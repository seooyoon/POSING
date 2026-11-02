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

    /// 이 값보다 화면이 위 · 아래를 향하면 십자 수평계 (중력 z 성분)
    static let flatThreshold = 0.9
    /// 십자 수평계가 맞았다고 보는 기울기 (중력 x · y 성분, 약 1도)
    static let flatTolerance = 0.018

    /// 좌우 기울기 (도). 폰을 눕혔거나 많이 기울이면 nil
    private(set) var roll: Double?
    /// 바닥 · 하늘을 향할 때 기울기 (중력의 화면 방향 성분, 화면 좌표: 오른쪽 · 아래가 +). 아니면 nil
    private(set) var flatTilt: CGVector?

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
    }

    private func update(gravity: CMAcceleration) {
        // 화면이 하늘이나 땅을 향하면 기본 카메라처럼 십자 수평계
        flatTilt = abs(gravity.z) > Self.flatThreshold ? CGVector(dx: gravity.x, dy: -gravity.y) : nil
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
