//
//  OpacityDragLabel.swift
//  포징
//
//  미리보기를 밀어 투명도를 바꾸는 동안 위쪽 가운데에 "MY 35%"를 잠깐 띄움 (docs/02_UI.md 3절).
//  밀고 있는 레이어의 패널이 열려 있으면 패널의 조절 바가 같은 값을 보여주므로 숨김.
//

import SwiftUI

struct OpacityDragLabel: View {

    let layers: LayerState
    /// 지금 밀고 있는 레이어. nil이면 숨김
    let kind: LayerKind?
    /// 상단 바에 가리지 않게 띄울 거리
    let topInset: CGFloat

    var body: some View {
        let value = kind.map { layers[$0].opacity } ?? 0
        let isShown = kind != nil && layers.openPanel != kind
        HStack(spacing: 6) {
            // MY 기능의 버튼 이름도 "포즈"
            Text("포즈")
                .foregroundStyle(.white)
            Text("\(Int((value * 100).rounded()))%")
                .foregroundStyle(Color.cameraYellow)
                .monospacedDigit()
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5), in: .capsule)
        .rotatesWithDevice()
        .opacity(isShown ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isShown)
        // 그 레이어의 패널이 열려 있으면 조절 바가 햅틱을 줌
        .sensoryFeedback(.selection, trigger: value) { _, _ in isShown }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, topInset + 12)
        .allowsHitTesting(false)
    }
}

extension LayerState {

    /// 미리보기 밀기로 투명도를 바꿀 레이어: 열린 패널 쪽, 아니면 MY, 그다음 포즈. 선택된 레이어가 없으면 nil
    var opacityDragTarget: LayerKind? {
        if let openPanel, self[openPanel].isSelected { return openPanel }
        if my.isSelected { return .my }
        return pose.isSelected ? .pose : nil
    }

    /// 시작 투명도에 민 비율을 더해 5% 단위로 맞춤
    func setOpacity(_ kind: LayerKind, from start: Double, dragged fraction: Double) {
        let range = AppDefaults.opacityRange(for: kind)
        let step = AppDefaults.opacityStep
        let snapped = ((start + fraction) / step).rounded() * step
        self[kind].opacity = min(max(snapped, range.lowerBound), range.upperBound)
    }
}
