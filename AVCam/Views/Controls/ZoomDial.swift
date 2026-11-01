//
//  ZoomDial.swift
//  포징
//
//  배율 다이얼: 위쪽만 보이는 큰 반원에 0.5×~25× 눈금. 지금 배율이 맨 위 가운데에 오도록 눈금이 돈다.
//  손가락 동작은 ZoomControl이 받는다.
//

import SwiftUI

struct ZoomDial: View {

    let zoom: ZoomState

    /// 배율이 2배가 될 때 다이얼이 도는 각도
    private let degreesPerDoubling: Double = 16
    /// 눈금 반원 위쪽 끝의 높이
    private let arcTop: CGFloat = 40

    var body: some View {
        Canvas { context, size in
            let radius = size.width * 1.3
            let center = CGPoint(x: size.width / 2, y: arcTop + radius)

            // 반투명 반원 판
            let disc = Path(ellipseIn: CGRect(x: center.x - radius - 30, y: arcTop - 30,
                                              width: (radius + 30) * 2, height: (radius + 30) * 2))
            context.fill(disc, with: .color(.black.opacity(0.4)))

            for value in Self.tickValues where zoom.range.contains(value) {
                let angle = self.angle(for: value)
                guard abs(angle) < .pi * 0.2 else { continue }
                let isMajor = ZoomState.presetValues.contains(value)
                let direction = CGVector(dx: sin(angle), dy: -cos(angle))
                let outer = point(center, direction, radius)
                let inner = point(center, direction, radius - (isMajor ? 12 : 7))
                var tick = Path()
                tick.move(to: outer)
                tick.addLine(to: inner)
                context.stroke(tick, with: .color(.white.opacity(isMajor ? 1 : 0.7)), lineWidth: isMajor ? 1.5 : 1)
                if isMajor {
                    let label = Text(ZoomState.label(value)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    context.draw(label, at: point(center, direction, radius - 24))
                }
            }

            // 맨 위 가운데: 노란 표시 + 지금 배율
            var marker = Path()
            marker.move(to: CGPoint(x: center.x - 5, y: arcTop - 8))
            marker.addLine(to: CGPoint(x: center.x + 5, y: arcTop - 8))
            marker.addLine(to: CGPoint(x: center.x, y: arcTop - 1))
            marker.closeSubpath()
            context.fill(marker, with: .color(.cameraYellow))
            let current = Text(ZoomState.label(zoom.displayFactor) + "×")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.cameraYellow)
            context.draw(current, at: CGPoint(x: center.x, y: arcTop - 22))
        }
    }

    /// 지금 배율 기준 각도 (라디안). 큰 배율일수록 오른쪽
    private func angle(for value: CGFloat) -> Double {
        log2(value / zoom.displayFactor) * degreesPerDoubling * .pi / 180
    }

    private func point(_ center: CGPoint, _ direction: CGVector, _ length: CGFloat) -> CGPoint {
        CGPoint(x: center.x + direction.dx * length, y: center.y + direction.dy * length)
    }

    /// 눈금 값: 0.5~2는 0.1 단위, 2~10은 0.5 단위, 10~25는 1 단위
    private static let tickValues: [CGFloat] = {
        let fine = stride(from: 5, through: 20, by: 1).map { CGFloat($0) / 10 }
        let medium = stride(from: 25, through: 100, by: 5).map { CGFloat($0) / 10 }
        let coarse = stride(from: 11, through: 25, by: 1).map { CGFloat($0) }
        return fine + medium + coarse
    }()
}
