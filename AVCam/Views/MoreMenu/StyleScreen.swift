//
//  StyleScreen.swift
//  포징
//
//  스타일 화면의 글자 · 버튼 (docs/01_SPEC.md 8절 스타일 화면, docs/02_UI.md 8-1절).
//  미리보기 카드는 CameraView가 줄여서 그리고, 여기서는 그 위아래 표시만 그린다.
//

import SwiftUI

/// 스타일 화면 배치 (기본 카메라 참고 화면에서 잰 값)
struct StyleScreenLayout {

    static let cardInset: CGFloat = 17
    static let cardCornerRadius: CGFloat = 24
    /// 이웃 카드와의 간격
    static let cardGap: CGFloat = 10
    /// 카드 위쪽이 원래 미리보기 위쪽보다 내려오는 양
    static let cardTopOffset: CGFloat = 5
    static let padSize: CGFloat = 118
    static let padTopGap: CGFloat = 17
    static let sliderSize = CGSize(width: 100, height: 20)
    static let sliderTopGap: CGFloat = 11
    static let closeButtonCenterX: CGFloat = 62
    /// 셔터는 카드 아래쪽 안으로 올라옴
    static let shutterAboveCardBottom: CGFloat = 50

    let cardRect: CGRect
    /// 미리보기를 카드로 줄이는 배율
    let scale: CGFloat

    init(layout: CameraLayout) {
        let preview = layout.previewRect
        let width = layout.size.width - Self.cardInset * 2
        // 16:9처럼 긴 미리보기도 4:3 카드 높이를 넘지 않게
        let maxHeight = width * 4 / 3
        scale = min(width / preview.width, maxHeight / preview.height)
        let size = CGSize(width: preview.width * scale, height: preview.height * scale)
        let top = layout.standardPhotoRect.minY + Self.cardTopOffset
        cardRect = CGRect(x: (layout.size.width - size.width) / 2, y: top, width: size.width, height: size.height)
    }

    var shutterCenterY: CGFloat { cardRect.maxY - Self.shutterAboveCardBottom }
    var padCenterY: CGFloat { cardRect.maxY + Self.padTopGap + Self.padSize / 2 }
    var sliderCenterY: CGFloat { padCenterY + Self.padSize / 2 + Self.sliderTopGap + Self.sliderSize.height / 2 }
}

/// 카드 위 · 아래 글자와 패드 · 슬라이더 · 닫기 버튼
struct StyleScreenControls: View {

    let styles: StyleState
    let layout: CameraLayout
    let onClose: () -> Void

    var body: some View {
        let style = StyleScreenLayout(layout: layout)
        let card = style.cardRect
        ZStack(alignment: .topLeading) {
            // 양옆 이웃 스타일 카드 (가장자리만 살짝 보임). 처음 · 마지막 스타일은 한쪽만
            ForEach([-1, 1], id: \.self) { side in
                let neighbor = styles.index + side
                if PhotoStyle.allCases.indices.contains(neighbor) {
                    RoundedRectangle(cornerRadius: StyleScreenLayout.cardCornerRadius, style: .continuous)
                        .fill(Color(white: 0.2))
                        .frame(width: card.width, height: card.height)
                        .position(x: card.midX + CGFloat(side) * (card.width + StyleScreenLayout.cardGap), y: card.midY)
                        .allowsHitTesting(false)
                }
            }
            StyleValuesCapsule(selection: styles.selection)
                .position(x: layout.centerX, y: card.minY - 38)
            Text(styles.style.preset.category)
                .styleCapsule()
                .position(x: card.midX, y: card.minY + 22)
            VStack(spacing: 14) {
                Text(styles.style.preset.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 6))
                StylePageDots(index: styles.index)
            }
            .position(x: card.midX, y: style.shutterCenterY - 92)

            StylePad(styles: styles)
                .frame(width: StyleScreenLayout.padSize, height: StyleScreenLayout.padSize)
                .position(x: layout.centerX, y: style.padCenterY)
            if styles.style.preset.hasPalette {
                PaletteSlider(styles: styles)
                    .frame(width: StyleScreenLayout.sliderSize.width, height: StyleScreenLayout.sliderSize.height)
                    .position(x: layout.centerX, y: style.sliderCenterY)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(white: 0.12), in: .circle)
            }
            .accessibilityLabel("스타일 닫기")
            .position(x: StyleScreenLayout.closeButtonCenterX, y: style.padCenterY)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .accessibilityAction(.escape, onClose)
    }
}

/// `톤 40  색상 -10  팔레트 80` (표준은 톤 · 색상만)
private struct StyleValuesCapsule: View {

    let selection: StyleSelection

    var body: some View {
        HStack(spacing: 18) {
            item("톤", selection.values.tone)
            item("색상", selection.values.color)
            if selection.style.preset.hasPalette {
                item("팔레트", selection.values.palette)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 27)
        .background(Color(white: 0.1), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func item(_ title: String, _ value: Double) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 14))
            Text(Self.format(value))
                .font(.cameraDigits(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
    }

    /// 0은 `00`, 마이너스만 부호 (참고 화면과 같음)
    static func format(_ value: Double) -> String {
        let number = Int(value.rounded())
        return number == 0 ? "00" : "\(number)"
    }
}

/// 현재 스타일 위치를 보여주는 점
private struct StylePageDots: View {

    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhotoStyle.allCases.indices, id: \.self) { position in
                Circle()
                    .fill(.white.opacity(position == index ? 1 : 0.45))
                    .frame(width: position == index ? 7 : 5, height: position == index ? 7 : 5)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// 카드 위 `색조` · `무드` 캡슐
    func styleCapsule() -> some View {
        font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(.black.opacity(0.55), in: .capsule)
    }
}
