//
//  OpacitySlider.swift
//  포징
//
//  투명도 조절 바: 왼쪽에 현재 값, 오른쪽에 가로 눈금 (기본 카메라 노출 눈금 바 느낌).
//  5% 단위로 맞추고 값이 바뀔 때 가벼운 햅틱 (docs/02_UI.md 3절).
//

import SwiftUI

struct OpacitySlider: View {

    @Binding var value: Double
    var isEnabled: Bool

    private let range = AppDefaults.opacityRange
    private let step = AppDefaults.opacityStep
    private var tickCount: Int { Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1 }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(isEnabled ? Color.cameraYellow : .white)
                .frame(width: 40, alignment: .leading)

            GeometryReader { proxy in
                ticks(width: proxy.size.width)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                value = snappedValue(at: gesture.location.x, width: proxy.size.width)
                            }
                    )
            }
            .frame(height: 24)
        }
        .opacity(isEnabled ? 1 : 0.35)
        .allowsHitTesting(isEnabled)
        .sensoryFeedback(.selection, trigger: value)
    }

    /// 지금 값까지는 밝은 눈금, 지금 값 자리에는 노란 긴 눈금
    private func ticks(width: CGFloat) -> some View {
        let current = Int(((value - range.lowerBound) / step).rounded())
        return HStack(spacing: 0) {
            ForEach(0..<tickCount, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.cameraYellow : .white.opacity(index < current ? 0.9 : 0.4))
                    .frame(width: index == current ? 2 : 1, height: index == current ? 20 : (index % 4 == 3 ? 12 : 8))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width, height: 24)
    }

    private func snappedValue(at x: CGFloat, width: CGFloat) -> Double {
        let ratio = min(max(x / max(width, 1), 0), 1)
        let index = (ratio * Double(tickCount - 1)).rounded()
        return range.lowerBound + index * step
    }
}

#Preview {
    @Previewable @State var value = 0.35
    OpacitySlider(value: $value, isEnabled: true)
        .padding()
        .background(.black)
}
