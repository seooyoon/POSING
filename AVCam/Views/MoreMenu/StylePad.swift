//
//  StylePad.swift
//  포징
//
//  조절 패드(가로 = 색상, 세로 = 톤)와 팔레트 슬라이더 (docs/02_UI.md 8-1절).
//  패드를 두 번 탭하면 그 스타일 기본값으로 되돌린다.
//

import SwiftUI

/// 스타일마다 패드 · 슬라이더가 은은하게 물드는 색
extension PhotoStyle {
    var tint: Color {
        switch self {
        case .standard: Color(white: 0.35)
        case .neutral: Color(red: 0.62, green: 0.52, blue: 0.47)
        case .dramatic: Color(red: 0.18, green: 0.42, blue: 0.58)
        case .elegant: Color(red: 0.36, green: 0.46, blue: 0.6)
        case .softMono: Color(white: 0.5)
        case .starkMono: Color(white: 0.2)
        }
    }
}

struct StylePad: View {

    let styles: StyleState

    private static let dotCount = 11
    private static let inset: CGFloat = 11
    private static let cornerRadius: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            let step = (size - Self.inset * 2) / CGFloat(Self.dotCount - 1)
            let current = point(tone: styles.current.tone, color: styles.current.color, size: size)
            let defaults = styles.style.preset.defaults
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [styles.style.tint.opacity(0.75), Color(white: 0.14)],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
                Canvas { context, _ in
                    let column = Int(((current.x - Self.inset) / step).rounded())
                    let row = Int(((current.y - Self.inset) / step).rounded())
                    for x in 0..<Self.dotCount {
                        for y in 0..<Self.dotCount {
                            let isLine = x == column || y == row
                            let radius: CGFloat = isLine ? 1.6 : 1.1
                            let center = CGPoint(x: Self.inset + CGFloat(x) * step, y: Self.inset + CGFloat(y) * step)
                            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                                width: radius * 2, height: radius * 2)),
                                         with: .color(.white.opacity(isLine ? 0.95 : 0.4)))
                        }
                    }
                }
                // 기본값 자리 작은 원
                Circle()
                    .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                    .frame(width: 7, height: 7)
                    .position(point(tone: defaults.tone, color: defaults.color, size: size))
                Circle()
                    .fill(.white)
                    .frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(current)
            }
            .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                let inner = size - Self.inset * 2
                let color = (value.location.x - Self.inset) / inner * 200 - 100
                let tone = 100 - (value.location.y - Self.inset) / inner * 200
                styles.setPad(tone: tone, color: color)
            })
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) { styles.resetCurrent() }
            }
        }
        .sensoryFeedback(.selection, trigger: styles.current.tone == 0 && styles.current.color == 0)
        .accessibilityElement()
        .accessibilityLabel("톤과 색상")
        .accessibilityValue("톤 \(Int(styles.current.tone)), 색상 \(Int(styles.current.color))")
        .accessibilityAdjustableAction { direction in
            let delta: Double = direction == .increment ? 10 : -10
            styles.setPad(tone: styles.current.tone + delta, color: styles.current.color)
        }
    }

    /// 값 → 패드 안 위치 (위 = 톤 +100, 오른쪽 = 색상 +100)
    private func point(tone: Double, color: Double, size: CGFloat) -> CGPoint {
        let inner = size - Self.inset * 2
        return CGPoint(x: Self.inset + (color + 100) / 200 * inner,
                       y: Self.inset + (100 - tone) / 200 * inner)
    }
}

/// 팔레트 0~100. 오른쪽으로 갈수록 스타일 색이 진해짐
struct PaletteSlider: View {

    let styles: StyleState

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let knob = height - 3
            let x = knob / 2 + 1.5 + (width - knob - 3) * styles.current.palette / 100
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.3), styles.style.tint], startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .position(x: x, y: height / 2)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                // 움직일 폭이 없으면 값이 NaN이 되므로 건너뜀
                guard width > knob else { return }
                styles.setPalette((value.location.x - knob / 2) / (width - knob) * 100)
            })
        }
        .accessibilityElement()
        .accessibilityLabel("팔레트")
        .accessibilityValue("\(Int(styles.current.palette))")
        .accessibilityAdjustableAction { direction in
            styles.setPalette(styles.current.palette + (direction == .increment ? 10 : -10))
        }
    }
}
