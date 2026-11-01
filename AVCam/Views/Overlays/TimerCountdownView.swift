//
//  TimerCountdownView.swift
//  포징
//
//  타이머 카운트다운: 미리보기 가운데 큰 숫자, 1초마다 햅틱 (docs/01_SPEC.md 8절).
//

import SwiftUI

struct TimerCountdownView: View {

    let countdown: Int?

    var body: some View {
        ZStack {
            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 140, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: countdown)
        .sensoryFeedback(.impact(weight: .light), trigger: countdown) { _, new in new != nil }
        .allowsHitTesting(false)
    }
}

#Preview {
    TimerCountdownView(countdown: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gray)
}
