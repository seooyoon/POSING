//
//  SplitPreviewOverlay.swift
//  포징
//
//  분할 사진의 미리보기 표시 (docs/02_UI.md 7절). 모두 화면에만 그리고 저장본에는 없음.
//  미리보기 자리를 칸으로 나눠, 지금 칸에는 실시간 화면(미리보기를 줄여 옮김), 나머지 칸에는 찍은 사진 또는 번호.
//  나머지 칸은 눌러도 아무 동작 없음 (다시 찍기는 오른쪽 위 토글 목록에서만)
//

import SwiftUI

/// 분할 칸 보기 계산. 좌표는 미리보기 자리 기준
@MainActor
struct SplitPreviewGeometry {

    let split: SplitShotState
    let previewSize: CGSize
    /// 사진 모드에서만 분할 표시 (비디오로 바꾸면 비율이 바뀌어 보이지 않게)
    let isEnabled: Bool

    /// 칸에 저장되는 영역: 사진 가운데를 칸 비율로 자른 크기
    static func cropSize(for cell: CGSize, in size: CGSize) -> CGSize {
        guard cell.width > 0, cell.height > 0 else { return size }
        let cellAspect = cell.width / cell.height
        return cellAspect > size.width / size.height
            ? CGSize(width: size.width, height: size.width / cellAspect)
            : CGSize(width: size.height * cellAspect, height: size.height)
    }

    /// 분할 칸 보기 중 (미리보기를 미리보기 자리로 자르고, 바깥 4:3 부분은 비치지 않음)
    var isShowing: Bool { isEnabled && split.isActive }

    /// 지금 칸에 저장될 영역 크기 (칸 보기가 아니거나 다 찍었으면 nil)
    var cropSize: CGSize? {
        guard isShowing, let index = split.currentIndex else { return nil }
        return Self.cropSize(for: split.layout.cellRect(index, in: previewSize).size, in: previewSize)
    }

    /// 미리보기를 지금 칸으로 옮기는 값 (배율, 가운데 이동). 아니면 nil
    var cellTransform: (scale: CGFloat, offset: CGSize)? {
        guard let crop = cropSize, let index = split.currentIndex else { return nil }
        let cell = split.layout.cellRect(index, in: previewSize)
        return (cell.width / crop.width,
                CGSize(width: cell.midX - previewSize.width / 2, height: cell.midY - previewSize.height / 2))
    }

    /// 칸 보기에서 누른 자리 → 원래 미리보기 자리 (초점 위치용)
    func unprojected(_ location: CGPoint) -> CGPoint {
        guard let transform = cellTransform else { return location }
        let center = CGPoint(x: previewSize.width / 2 + transform.offset.width,
                             y: previewSize.height / 2 + transform.offset.height)
        return CGPoint(x: previewSize.width / 2 + (location.x - center.x) / transform.scale,
                       y: previewSize.height / 2 + (location.y - center.y) / transform.scale)
    }
}

/// 칸 보기면 미리보기 · 레이어를 지금 칸으로 줄여 옮김.
/// fitsCrop: 격자 · 수평계처럼 먼저 저장될 영역 크기로 맞춘 뒤 옮김 (칸에 꼭 맞게).
/// 분기(if)로 감싸면 뷰가 새로 만들어져 수평계 센서가 꺼질 수 있어서, 같은 뷰에 값만 바꿈
struct SplitCellTransform: ViewModifier {

    let geometry: SplitPreviewGeometry
    var fitsCrop = false

    func body(content: Content) -> some View {
        let transform = geometry.cellTransform
        let crop = fitsCrop ? geometry.cropSize : nil
        content
            .frame(width: crop?.width, height: crop?.height)
            .scaleEffect(transform?.scale ?? 1)
            .offset(transform?.offset ?? .zero)
            .animation(.easeInOut(duration: 0.25), value: transform?.scale)
            .animation(.easeInOut(duration: 0.25), value: transform?.offset)
    }
}

/// 칸 보기: 지금 칸은 비워 둠(실시간 화면이 보임), 나머지 칸은 찍은 사진 또는 번호 (눌러도 동작 없음)
struct SplitPreviewOverlay: View {

    let geometry: SplitPreviewGeometry

    var body: some View {
        let split = geometry.split
        GeometryReader { proxy in
            if geometry.isShowing {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<split.layout.count, id: \.self) { index in
                        if index != split.currentIndex {
                            let rect = split.layout.cellRect(index, in: proxy.size)
                            SplitCellImage(shot: split.shot(at: index), number: index + 1,
                                           isPending: split.pendingIndices.contains(index))
                                .frame(width: rect.width, height: rect.height)
                                // 눌러도 아무 동작 없음 (다시 찍기는 토글 목록에서만). 아래 미리보기로 초점이 가지 않게 터치만 받음
                                .contentShape(.rect)
                                .onTapGesture {}
                                .offset(x: rect.minX, y: rect.minY)
                        }
                    }
                }
            }
        }
    }
}

/// 칸 하나: 찍은 사진(칸에 꽉 차게, 가운데, 칸 밖은 잘라냄) 또는 어두운 칸에 번호
struct SplitCellImage: View {

    let shot: SplitShot?
    let number: Int
    var isPending = false
    var numberSize: CGFloat = 22
    /// 이미 돌린 묶음 안이면 번호를 따로 돌리지 않음
    var rotatesNumber = true
    /// 안 찍은 칸 바탕 · 번호 색
    var emptyColor = Color(white: AppDefaults.splitEmptyCellGray)
    var numberColor = Color.white.opacity(0.7)

    var body: some View {
        // 바탕 색이 칸 크기를 정하고 사진은 그 위에 꽉 채워 잘라냄 (칸 밖으로 넘치지 않게)
        emptyColor
            .overlay {
                if let image = shot?.thumbnail {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay { placeholder }
            .clipped()
    }

    @ViewBuilder
    private var placeholder: some View {
        if shot?.thumbnail != nil {
            EmptyView()
        } else if isPending {
            ProgressView()
                .tint(.white)
        } else {
            Text("\(number)")
                .font(.system(size: numberSize, weight: .semibold))
                .foregroundStyle(numberColor)
                .modifier(OptionalDeviceRotation(isOn: rotatesNumber))
        }
    }
}

/// 켜져 있을 때만 기기 방향대로 돌림
private struct OptionalDeviceRotation: ViewModifier {
    let isOn: Bool
    func body(content: Content) -> some View {
        if isOn { content.rotatesWithDevice() } else { content }
    }
}
