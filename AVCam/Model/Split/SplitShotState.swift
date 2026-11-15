//
//  SplitShotState.swift
//  포징
//
//  분할 사진 (docs/01_SPEC.md 7-2절). 1(기본) · 2 · 3 · 4분할을 고르고 칸마다 한 장씩 찍어 둔다.
//  찍은 사진은 저장 버튼을 누를 때까지 메모리에만 두고, 저장하면 합친 사진(+ 칸별 원본)을 사진 앱에 넣는다.
//

import SwiftUI
import ImageIO

/// 분할 모양. 칸 자리는 전체를 1로 본 위에서부터의 비율 (1 · 2번이 위)
enum SplitLayout: Int, CaseIterable, Identifiable, Sendable {
    case single = 1
    case two = 2
    case three = 3
    case four = 4

    var id: Int { rawValue }
    var count: Int { rawValue }

    /// 칸 자리 (x, y, 폭, 높이를 전체 대비 0~1로). 2 · 3분할은 세로로 쌓고, 4분할은 2×2
    var cells: [CGRect] {
        switch self {
        case .single: [CGRect(x: 0, y: 0, width: 1, height: 1)]
        case .two: (0..<2).map { CGRect(x: 0, y: CGFloat($0) / 2, width: 1, height: 0.5) }
        case .three: (0..<3).map { CGRect(x: 0, y: CGFloat($0) / 3, width: 1, height: 1.0 / 3) }
        case .four: (0..<4).map { CGRect(x: CGFloat($0 % 2) / 2, y: CGFloat($0 / 2) / 2, width: 0.5, height: 0.5) }
        }
    }

    /// `size` 안의 칸 자리
    func cellRect(_ index: Int, in size: CGSize) -> CGRect {
        let unit = cells[index]
        return CGRect(x: unit.minX * size.width, y: unit.minY * size.height,
                      width: unit.width * size.width, height: unit.height * size.height)
    }
}

/// 한 칸의 사진
struct SplitShot: Sendable {
    /// 저장할 사진 데이터 (색감 · 비율 자르기까지 끝난 것)
    let data: Data
    /// 칸 목록 · 전체 보기에 쓰는 작은 그림 (방향 적용)
    let thumbnail: CGImage?

    /// 데이터에서 작은 그림을 만들어 칸 사진으로
    nonisolated static func make(from data: Data) -> SplitShot {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: AppDefaults.splitThumbnailPixelSize,
        ]
        let thumbnail = CGImageSourceCreateWithData(data as CFData, nil).flatMap {
            CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
        }
        return SplitShot(data: data, thumbnail: thumbnail)
    }
}

@MainActor
@Observable
final class SplitShotState {

    /// 고른 분할. 바꾸면 찍어 둔 사진은 지움
    var layout = SplitLayout.single {
        didSet {
            guard layout != oldValue else { return }
            reset()
        }
    }
    /// 오른쪽 위 토글: 칸별 사진 목록 열림
    var isPanelOpen = AppDefaults.isSplitPanelOpen
    /// 칸별 사진 (찍지 않은 칸은 nil)
    private(set) var shots: [SplitShot?] = [nil]
    /// 다음에 찍을 칸. 모두 찍었으면 nil
    private(set) var currentIndex: Int?
    /// 찍는 중(처리 중)인 칸
    private(set) var pendingIndices: Set<Int> = []
    /// 저장 중
    var isSaving = false
    /// 분할을 바꾸거나 저장하면 바뀜 (그 전에 찍기 시작한 사진이 새 칸에 들어가지 않게)
    private(set) var session = 0

    var isActive: Bool { layout != .single }

    /// 모든 칸을 찍었고 다시 찍으려고 고른 칸도 없음 (셔터가 저장 버튼이 됨).
    /// 토글 목록에서 칸을 골라 다시 찍는 동안은 셔터 그대로
    var isComplete: Bool {
        isActive && currentIndex == nil && pendingIndices.isEmpty && shots.allSatisfy { $0 != nil }
    }

    /// 셔터를 누르면 찍을 칸 (분할이 아니거나 모두 찍었으면 nil)
    var captureIndex: Int? { isActive ? currentIndex : nil }

    func reset() {
        shots = Array(repeating: nil, count: layout.count)
        pendingIndices = []
        currentIndex = isActive ? 0 : nil
        session += 1
    }

    /// 칸을 눌러 그 칸을 (다시) 찍기.
    /// 다시 찍으려고 고른 칸을 한 번 더 누르면 취소: 찍어 둔 사진을 그대로 두고 다음 빈 칸으로 (모두 찍었으면 없음)
    func select(_ index: Int) {
        guard shots.indices.contains(index), !pendingIndices.contains(index) else { return }
        if index == currentIndex, shots[index] != nil {
            currentIndex = nextEmptyIndex(after: index)
        } else {
            currentIndex = index
        }
    }

    /// 셔터 순간: 지금 칸을 찍는 중으로 두고 다음 빈 칸으로 넘어감
    func beginCapture(at index: Int) {
        pendingIndices.insert(index)
        currentIndex = nextEmptyIndex(after: index)
    }

    /// 처리가 끝난 사진을 칸에 넣음. 실패(nil)면 그 칸을 다시 찍을 수 있게
    func finishCapture(_ shot: SplitShot?, at index: Int, session: Int) {
        guard session == self.session, shots.indices.contains(index) else { return }
        pendingIndices.remove(index)
        if let shot {
            shots[index] = shot
        } else if currentIndex == nil {
            currentIndex = index
        }
    }

    /// `index` 다음부터 한 바퀴 돌며 찍지 않았고 찍는 중도 아닌 칸
    private func nextEmptyIndex(after index: Int) -> Int? {
        let count = shots.count
        return (1...count).lazy
            .map { (index + $0) % count }
            .first { self.shots[$0] == nil && !self.pendingIndices.contains($0) }
    }
}
