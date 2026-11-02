//
//  LevelOverlay.swift
//  포징
//
//  수평계: 화면 가운데 가로선. 양옆 짧은 선은 고정, 가운데 선은 기울기만큼 돌아가고,
//  수평(±1°)이 되면 하나로 이어지며 노랗게 바뀐다.
//  화면이 바닥 · 하늘을 거의 똑바로 향하면 가운데 흰 십자와 기울기만큼 비켜 난 노란 십자. 겹치면 노란 십자 하나가 된다.
//  똑바로에서 벗어날수록 흐려지다가 사라진다.
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
            if let tilt = level.flatTilt {
                if !isFlat {
                    cross(color: .white)
                }
                cross(color: .cameraYellow)
                    .offset(x: isFlat ? 0 : tilt.dx * crossTravel, y: isFlat ? 0 : tilt.dy * crossTravel)
            }
        }
        // 십자만 각도에 따라 흐려짐 (가로선 수평계와는 동시에 나오지 않음)
        .opacity(level.flatTilt == nil ? 1 : level.flatOpacity)
        .allowsHitTesting(false)
        .onAppear { level.start() }
        .onDisappear { level.stop() }
    }

    /// 중력 성분 1당 노란 십자가 움직이는 거리
    private let crossTravel: CGFloat = 400

    private var isFlat: Bool {
        guard let tilt = level.flatTilt else { return false }
        return hypot(tilt.dx, tilt.dy) <= LevelModel.flatTolerance
    }

    private func cross(color: Color) -> some View {
        ZStack {
            Capsule().fill(color).frame(width: 24, height: 1.5)
            Capsule().fill(color).frame(width: 1.5, height: 24)
        }
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: 1.5)
    }
}
