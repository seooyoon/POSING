//
//  FocusModel.swift
//  포징
//
//  화면에 보이는 초점 사각형 · 해 아이콘 · AE/AF 잠금 표시 상태 (docs/01_SPEC.md 7절, docs/02_UI.md 5절).
//  실제 초점 · 노출 설정은 CaptureService가 하고, 여기는 표시만 관리한다.
//

import SwiftUI

@MainActor
@Observable
final class FocusModel {

    /// 밝기 조절 범위 (EV). 장치 범위로는 CaptureService에서 한 번 더 제한
    static let biasRange: ClosedRange<Float> = -2...2
    /// 손가락을 이만큼(pt) 움직이면 1 EV
    private static let pointsPerEV = CGFloat(AppDefaults.focusBiasPointsPerEV)
    /// 탭 후 사각형이 흐려지기까지 (초)
    private static let dimDelay: Duration = .seconds(2)
    /// 잠금이 아닐 때 표시가 사라지기까지 (초)
    private static let hideDelay: Duration = .seconds(8)

    /// 미리보기 안의 초점 위치. nil이면 표시 없음
    private(set) var point: CGPoint?
    private(set) var isLocked = false
    private(set) var isDimmed = false
    private(set) var bias: Float = 0
    /// 위아래로 밀어 밝기를 바꾸는 중
    private(set) var isAdjusting = false
    /// 새로 탭할 때마다 바뀜 (사각형 등장 애니메이션 트리거)
    private(set) var tapCount = 0

    private var dragStartBias: Float?
    private var dimTask: Task<Void, Never>?

    func tap(at location: CGPoint) {
        show(at: location, locked: false)
    }

    func lock(at location: CGPoint) {
        show(at: location, locked: true)
    }

    /// 밝기 조절은 초점 사각형 · 해 아이콘 근처에서 시작한 밀기만 (스치는 동작으로 바뀌지 않게)
    private static let adjustableSize = CGSize(width: 200, height: 240)

    func canAdjustBias(startingAt location: CGPoint) -> Bool {
        guard let point else { return false }
        return abs(location.x - point.x) <= Self.adjustableSize.width / 2
            && abs(location.y - point.y) <= Self.adjustableSize.height / 2
    }

    /// 위아래로 민 거리만큼 밝기 변경. 표시가 없으면 nil (밝기 조절 안 함)
    func adjustBias(byDragging translation: CGFloat) -> Float? {
        guard point != nil else { return nil }
        let start = dragStartBias ?? bias
        dragStartBias = start
        let value = start - Float(translation / Self.pointsPerEV)
        bias = min(max(value, Self.biasRange.lowerBound), Self.biasRange.upperBound)
        isAdjusting = true
        isDimmed = false
        scheduleDim()
        return bias
    }

    func endAdjusting() {
        dragStartBias = nil
        isAdjusting = false
    }

    /// 모드 · 카메라 전환 시 표시 지움
    func clear() {
        dimTask?.cancel()
        point = nil
        isLocked = false
        isDimmed = false
        bias = 0
        endAdjusting()
    }

    private func show(at location: CGPoint, locked: Bool) {
        point = location
        isLocked = locked
        isDimmed = false
        bias = 0
        tapCount += 1
        scheduleDim()
    }

    private func scheduleDim() {
        dimTask?.cancel()
        dimTask = Task {
            try? await Task.sleep(for: Self.dimDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { isDimmed = true }
            // 잠금 중에는 흐린 채로 남겨 둠
            guard !isLocked else { return }
            try? await Task.sleep(for: Self.hideDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { point = nil }
        }
    }
}
