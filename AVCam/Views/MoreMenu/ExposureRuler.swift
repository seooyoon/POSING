//
//  ExposureRuler.swift
//  포징
//
//  더보기 메뉴 노출: ±2 가로 눈금 바 (docs/01_SPEC.md 8절).
//  좌우로 밀면 눈금이 움직이고 가운데 노란 표시가 지금 값. 1/3 단위로 맞춰지고, 두 번 탭하면 0.
//

import SwiftUI

struct ExposureRuler: View {

    @Binding var value: Float

    /// 눈금 하나(1/3) 사이 간격
    private let tickSpacing: CGFloat = 16
    @State private var dragStartValue: Float?

    private var tickValues: [Float] {
        stride(from: ExposureCompensation.range.lowerBound,
               through: ExposureCompensation.range.upperBound + 0.01,
               by: ExposureCompensation.step).map { $0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(ExposureCompensation.label(value))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(abs(value) < 0.05 ? .white : Color.cameraYellow)
            ZStack {
                ticks
                    .offset(x: -CGFloat(value / ExposureCompensation.step) * tickSpacing)
                // 가운데 = 지금 값
                Capsule()
                    .fill(Color.cameraYellow)
                    .frame(width: 2, height: 26)
            }
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .clipped()
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .contentShape(.rect)
            .gesture(drag)
            .onTapGesture(count: 2) { value = 0 }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private var ticks: some View {
        HStack(spacing: tickSpacing - 1) {
            ForEach(tickValues, id: \.self) { tick in
                // 정수(0, ±1, ±2)는 길고 밝게
                let isMajor = abs(tick - tick.rounded()) < 0.01
                Capsule()
                    .fill(.white.opacity(isMajor ? 0.9 : 0.45))
                    .frame(width: 1, height: isMajor ? 18 : 10)
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let start = dragStartValue ?? value
                dragStartValue = start
                // 왼쪽으로 밀면 눈금이 왼쪽으로 → 값이 커짐
                let delta = Float(-gesture.translation.width / tickSpacing) * ExposureCompensation.step
                let next = ExposureCompensation.snapped(start + delta)
                if next != value { value = next }
            }
            .onEnded { _ in
                dragStartValue = nil
            }
    }
}

#Preview {
    ExposureRuler(value: .constant(0.67))
        .padding()
        .background(.black)
}
