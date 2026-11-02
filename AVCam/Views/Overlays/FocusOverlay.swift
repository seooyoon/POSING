//
//  FocusOverlay.swift
//  포징
//
//  초점 사각형(노란 얇은 사각형 + 모서리 중간 눈금) · 오른쪽 해 아이콘 · 상단 "AE/AF 잠금" 표시.
//  터치는 받지 않고 미리보기 제스처가 FocusModel을 바꾼다.
//

import SwiftUI

struct FocusOverlay: View {

    let focus: FocusModel
    /// 미리보기 위쪽에서 상단 바에 가려지는 높이. 잠금 표시는 그 아래에 둠 (비디오 · 16:9)
    var topInset: CGFloat = 0

    private let boxSize: CGFloat = 76
    /// 해 아이콘이 밝기에 따라 위아래로 움직이는 거리 (1 EV당)
    private let sunTravelPerEV: CGFloat = 26

    @State private var appearScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .top) {
            if let point = focus.point {
                indicator
                    .scaleEffect(appearScale)
                    .opacity(focus.isDimmed ? 0.45 : 1)
                    .position(point)
            }
            if focus.isLocked {
                lockBadge
                    .padding(.top, topInset + 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: focus.tapCount) {
            // 크게 나타났다가 줄어듦
            appearScale = 1.35
            withAnimation(.easeOut(duration: 0.25)) { appearScale = 1 }
        }
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            FocusBox()
                .stroke(Color.cameraYellow, lineWidth: 1)
                .frame(width: boxSize, height: boxSize)
            sunSlider
        }
        // 사각형 가운데가 탭한 자리에 오도록 해 아이콘 폭만큼 보정
        .offset(x: 13)
    }

    /// 해 아이콘. 밝기를 조절하는 동안에는 위아래 선이 보임
    private var sunSlider: some View {
        let offset = -CGFloat(focus.bias) * sunTravelPerEV
        return ZStack {
            if focus.isAdjusting || focus.bias != 0 {
                Rectangle()
                    .fill(Color.cameraYellow)
                    .frame(width: 1, height: boxSize + 40)
            }
            Image(systemName: "sun.max.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.cameraYellow)
                .offset(y: offset)
        }
        .frame(width: 18)
    }

    private var lockBadge: some View {
        Text("AE/AF 잠금")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.cameraYellow, in: .rect(cornerRadius: 4))
    }
}

/// 노란 사각형 + 네 변 가운데 안쪽으로 짧은 눈금
private struct FocusBox: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let tick: CGFloat = 5
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + tick))
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - tick))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + tick, y: rect.midY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - tick, y: rect.midY))
        return path
    }
}
