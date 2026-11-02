//
//  ZoomDial.swift
//  포징
//
//  배율 다이얼: 기본 카메라처럼 셔터 뒤까지 덮는 큰 반투명 원. 가장자리에 촘촘한 눈금,
//  안쪽에 원을 따라 기운 배율 숫자와 mm 표시. 지금 배율이 맨 위 가운데(노란 삼각형)에 오도록 원이 돈다.
//  손가락 동작은 ZoomControl이 받는다.
//

import SwiftUI

struct ZoomDial: View {

    /// 배율이 2배가 될 때 다이얼이 도는 각도
    static let degreesPerDoubling: Double = 16

    let zoom: ZoomState

    /// 큰 눈금 · 숫자를 그리는 배율과 mm 표시 (iPhone 16 Pro 렌즈 환산 화각)
    private static let labels: [(value: CGFloat, millimeters: Int?)] = [
        (0.5, 13), (1, 24), (2, 48), (5, 120), (25, nil),
    ]
    /// 28mm · 35mm 자리의 작은 점
    private static let dotValues: [CGFloat] = [1.2, 1.5]

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // 반투명 판
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.35)))

            // 가장자리 눈금
            for value in Self.tickValues where zoom.range.contains(value) {
                let angle = angle(for: value)
                guard abs(angle) < .pi / 2 else { continue }
                let isMajor = Self.labels.contains { abs($0.value - value) < 0.001 }
                var tick = Path()
                tick.move(to: point(center, angle, radius - 3))
                tick.addLine(to: point(center, angle, radius - (isMajor ? 16 : 9)))
                context.stroke(tick, with: .color(.white.opacity(isMajor ? 1 : 0.55)), lineWidth: isMajor ? 1.5 : 1)
            }

            // 28 · 35mm 점
            for value in Self.dotValues where zoom.range.contains(value) {
                let angle = angle(for: value)
                guard abs(angle) < .pi / 2, abs(angle) > 0.05 else { continue }
                let dot = point(center, angle, radius - 30)
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 1.5, y: dot.y - 1.5, width: 3, height: 3)),
                             with: .color(.white.opacity(0.8)))
            }

            // 숫자 · mm: 원을 따라 기울여 그림. 맨 위(지금 배율 자리) 근처는 숨김
            for label in Self.labels where zoom.range.contains(label.value) {
                let angle = angle(for: label.value)
                guard abs(angle) < .pi / 2, abs(angle) > 0.1 else { continue }
                context.drawLayer { layer in
                    let origin = point(center, angle, radius - 30)
                    layer.translateBy(x: origin.x, y: origin.y)
                    layer.rotate(by: .radians(angle))
                    layer.draw(Text(Self.title(label.value)).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white), at: .zero)
                    if let millimeters = label.millimeters {
                        layer.draw(Text("\(millimeters)MM").font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7)), at: CGPoint(x: 0, y: 14))
                    }
                }
            }

            // 맨 위 가운데: 노란 삼각형 + 지금 배율
            var marker = Path()
            marker.move(to: CGPoint(x: center.x - 5, y: 1))
            marker.addLine(to: CGPoint(x: center.x + 5, y: 1))
            marker.addLine(to: CGPoint(x: center.x, y: 8))
            marker.closeSubpath()
            context.fill(marker, with: .color(.cameraYellow))
            let current = Text(ZoomState.label(zoom.displayFactor) + "×")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.cameraYellow)
            context.draw(current, at: CGPoint(x: center.x, y: 30))
        }
    }

    /// 지금 배율 기준 각도 (라디안, 맨 위 = 0). 큰 배율일수록 오른쪽
    private func angle(for value: CGFloat) -> Double {
        log2(value / zoom.displayFactor) * Self.degreesPerDoubling * .pi / 180
    }

    private func point(_ center: CGPoint, _ angle: Double, _ length: CGFloat) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * length, y: center.y - cos(angle) * length)
    }

    /// 다이얼 숫자: 기본 카메라처럼 `0.5`, `1`, `25`
    private static func title(_ value: CGFloat) -> String {
        value < 1 ? "0.5" : ZoomState.label(value)
    }

    /// 눈금 값: 배율이 클수록 촘촘하지 않게. 0.5~2는 0.1, 2~5는 0.25, 5~10은 0.5, 10~25는 1 단위
    private static let tickValues: [CGFloat] = {
        let fine = stride(from: 5, through: 20, by: 1).map { CGFloat($0) / 10 }
        let medium = stride(from: 9, through: 20, by: 1).map { CGFloat($0) / 4 }
        let large = stride(from: 11, through: 20, by: 1).map { CGFloat($0) / 2 }
        let coarse = stride(from: 11, through: 25, by: 1).map { CGFloat($0) }
        return fine + medium + large + coarse
    }()
}
