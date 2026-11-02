//
//  LevelModel.swift
//  포징
//
//  수평계: 폰을 세워 들었을 때 좌우 기울기, 바닥 · 하늘을 향할 때 앞뒤 · 좌우 기울기 (docs/05_TECH_NOTES.md 11절, CoreMotion).
//

import CoreMotion
import SwiftUI

@MainActor
@Observable
final class LevelModel {

    /// 이 각도(도) 안으로 기울었을 때만 수평계 표시
    static let visibleRange = 10.0
    /// 이 각도(도) 안이면 수평으로 보고 노랗게 표시
    static let levelTolerance = 1.0

    /// 화면이 위 · 아래를 똑바로 향한 데서 이 각도(도) 안이면 십자 수평계가 또렷하게 보임
    static let flatOpaqueAngle = 3.0
    /// 이 각도(도)까지 점점 투명해지고, 넘으면 사라짐
    static let flatVisibleAngle = 8.0
    /// 십자 수평계가 맞았다고 보는 기울기 (중력 x · y 성분, 약 1도)
    static let flatTolerance = 0.018

    /// 좌우 기울기 (도). 폰을 눕혔거나 많이 기울이면 nil
    private(set) var roll: Double?
    /// 바닥 · 하늘을 향할 때 기울기 (중력의 화면 방향 성분, 화면 좌표: 오른쪽 · 아래가 +). 아니면 nil
    private(set) var flatTilt: CGVector?
    /// 십자 수평계 투명도: 똑바로 향할수록 1, flatVisibleAngle에서 0
    private(set) var flatOpacity = 0.0

    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let gravity = data?.gravity else { return }
            MainActor.assumeIsolated {
                self?.update(gravity: gravity)
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        roll = nil
        flatTilt = nil
        flatOpacity = 0
    }

    private func update(gravity: CMAcceleration) {
        // 화면이 하늘이나 땅을 거의 똑바로 향하면 기본 카메라처럼 십자 수평계. 벗어날수록 투명하게
        let flatAngle = asin(min(hypot(gravity.x, gravity.y), 1)) * 180 / .pi
        if flatAngle < Self.flatVisibleAngle {
            flatTilt = CGVector(dx: gravity.x, dy: -gravity.y)
            flatOpacity = min(1, (Self.flatVisibleAngle - flatAngle) / (Self.flatVisibleAngle - Self.flatOpaqueAngle))
        } else {
            flatTilt = nil
            flatOpacity = 0
        }
        // 비스듬히 눕혔을 때는 둘 다 표시하지 않음
        guard abs(gravity.z) < 0.8 else {
            roll = nil
            return
        }
        // 세로로 똑바로 들면 0도
        let degrees = atan2(gravity.x, -gravity.y) * 180 / .pi
        roll = abs(degrees) <= Self.visibleRange ? degrees : nil
    }
}
