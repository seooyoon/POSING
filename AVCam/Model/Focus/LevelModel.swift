//
//  LevelModel.swift
//  포징
//
//  수평계: 폰을 세워 들었을 때 좌우 기울기 (docs/05_TECH_NOTES.md 11절, CoreMotion).
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

    /// 좌우 기울기 (도). 폰을 눕혔거나 많이 기울이면 nil
    private(set) var roll: Double?

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
    }

    private func update(gravity: CMAcceleration) {
        // 화면이 하늘이나 땅을 향하면(폰을 눕힘) 표시하지 않음
        guard abs(gravity.z) < 0.8 else {
            roll = nil
            return
        }
        // 세로로 똑바로 들면 0도
        let degrees = atan2(gravity.x, -gravity.y) * 180 / .pi
        roll = abs(degrees) <= Self.visibleRange ? degrees : nil
    }
}
