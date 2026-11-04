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
        (0.5, 13), (1, 24), (2, nil), (5, 120), (25, nil),
    ]
    /// 길고 밝은 눈금 자리
    private static let majorTicks: [CGFloat] = [0.5, 1, 1.2, 1.5, 2, 3, 4, 5, 10, 25]
    /// 28mm · 35mm 자리의 작은 점
    private static let dotValues: [CGFloat] = [1.2, 1.5]
    /// 가장자리 ~ 숫자 줄 (기본 카메라에서 잰 값)
    private static let labelInset: CGFloat = 33

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // 반투명 판
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))

            // 가장자리 눈금
            for value in Self.tickValues where zoom.range.contains(value) {
                let angle = angle(for: value)
                // 맨 위는 노란 삼각형 자리라 눈금을 비움
                guard abs(angle) < .pi / 2, abs(angle) > 0.012 else { continue }
                let isMajor = Self.majorTicks.contains { abs($0 - value) < 0.001 }
                var tick = Path()
                tick.move(to: point(center, angle, radius - 5))
                tick.addLine(to: point(center, angle, radius - (isMajor ? 21 : 16)))
                context.stroke(tick, with: .color(.white.opacity(isMajor ? 0.95 : 0.3)), lineWidth: isMajor ? 1 : 0.75)
            }

            // 28 · 35mm 점
            for value in Self.dotValues where zoom.range.contains(value) {
                let angle = angle(for: value)
                guard abs(angle) < .pi / 2, abs(angle) > 0.05 else { continue }
                let dot = point(center, angle, radius - Self.labelInset)
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 1.5, y: dot.y - 1.5, width: 3, height: 3)),
                             with: .color(.white.opacity(0.8)))
            }

            // 숫자 · mm: 원을 따라 기울여 그림. 맨 위(지금 배율 자리) 근처는 숨김
            for label in Self.labels where zoom.range.contains(label.value) {
                let angle = angle(for: label.value)
                guard abs(angle) < .pi / 2, abs(angle) > 0.1 else { continue }
                context.drawLayer { layer in
                    let origin = point(center, angle, radius - Self.labelInset)
                    layer.translateBy(x: origin.x, y: origin.y)
                    layer.rotate(by: .radians(angle))
                    layer.draw(Text(Self.title(label.value)).font(.system(size: 15))
                        .foregroundStyle(.white), at: .zero)
                    if let millimeters = label.millimeters {
                        layer.draw(Text("\(millimeters)MM").font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5)), at: CGPoint(x: 0, y: 15))
                    }
                }
            }

            // 맨 위 가운데: 노란 삼각형 + 지금 배율
            var marker = Path()
            marker.move(to: CGPoint(x: center.x - 4, y: 3))
            marker.addLine(to: CGPoint(x: center.x + 4, y: 3))
            marker.addLine(to: CGPoint(x: center.x, y: 13))
            marker.closeSubpath()
            context.fill(marker, with: .color(.cameraYellow))
            let current = Text(ZoomState.activeLabel(zoom.displayFactor) + "×")
                .font(.cameraDigits(size: 15)).foregroundStyle(Color.cameraYellow)
            context.draw(current, at: CGPoint(x: center.x, y: 36))
            // 화각 이름이 있는 배율이면 아래에 mm
            if let millimeters = ZoomState.millimeters(zoom.displayFactor) {
                let name = Text("\(millimeters)MM").font(.system(size: 10)).foregroundStyle(Color.cameraYellow)
                context.draw(name, at: CGPoint(x: center.x, y: 51))
            }
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

    /// 눈금 값 (기본 카메라처럼 촘촘하게). 0.5~1은 0.1, 1~2는 0.05, 2~5는 0.1, 5~10은 0.2, 10~25는 0.5 단위
    private static let tickValues: [CGFloat] = {
        let wide = stride(from: 5, to: 10, by: 1).map { CGFloat($0) / 10 }
        let main = stride(from: 20, to: 40, by: 1).map { CGFloat($0) / 20 }
        let tele = stride(from: 20, to: 50, by: 1).map { CGFloat($0) / 10 }
        let long = stride(from: 25, to: 50, by: 1).map { CGFloat($0) / 5 }
        let far = stride(from: 20, through: 50, by: 1).map { CGFloat($0) / 2 }
        return wide + main + tele + long + far
    }()
}
