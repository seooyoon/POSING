//
//  LevelOverlay.swift
//  포징
//
//  수평계: 화면 가운데 가로선. 양옆 짧은 선은 고정, 가운데 선은 기울기만큼 돌아가고,
//  수평(±1°)이 되면 하나로 이어지며 노랗게 바뀐다.
//

import SwiftUI

struct LevelOverlay: View {

    let level: LevelModel

    var body: some View {
        ZStack {
            if let roll = level.roll {
                let isLevel = abs(roll) <= LevelModel.levelTolerance
                let color: Color = isLevel ? .cameraYellow : .white
                HStack(spacing: isLevel ? 0 : 10) {
                    segment(width: 28, color: color)
                    segment(width: 80, color: color)
                        // 화면은 세로로 고정이라, 폰이 기운 반대 방향으로 돌려 실제 수평을 보여줌
                        .rotationEffect(.degrees(isLevel ? 0 : -roll))
                    segment(width: 28, color: color)
                }
                .animation(.easeOut(duration: 0.15), value: isLevel)
            }
        }
        .allowsHitTesting(false)
        .onAppear { level.start() }
        .onDisappear { level.stop() }
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: 1.5)
    }
}
