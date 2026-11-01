//
//  GridOverlay.swift
//  포징
//
//  3x3 격자(얇은 흰 선)와 중심점(작은 십자). 설정 화면 스위치로 켜고 끈다 (docs/01_SPEC.md 6 · 7절).
//

import SwiftUI

struct GridOverlay: View {

    @AppStorage(SettingsKeys.isGridEnabled) private var isGridEnabled = AppDefaults.isGridEnabled
    @AppStorage(SettingsKeys.isCenterMarkEnabled) private var isCenterMarkEnabled = AppDefaults.isCenterMarkEnabled

    var body: some View {
        ZStack {
            if isGridEnabled {
                ThirdsGrid()
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            }
            if isCenterMarkEnabled {
                CenterMark()
                    .stroke(.white.opacity(0.9), lineWidth: 1)
                    .frame(width: 18, height: 18)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 1...2 {
            let x = rect.minX + rect.width * CGFloat(step) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(step) / 3
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

private struct CenterMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
