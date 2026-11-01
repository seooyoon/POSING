//
//  ZoomControl.swift
//  포징
//
//  배율 버튼 `.5 · 1 · 2 · 5` (docs/02_UI.md 6절). 현재 버튼만 어두운 원 + 노란 글씨 + `×`,
//  버튼 사이 배율이면 그 자리에 실제 값. 길게 누르거나 좌우로 밀면 반원 다이얼이 펼쳐지고 손을 떼면 1.5초 뒤 접힌다.
//

import SwiftUI

struct ZoomControl<CameraModel: Camera>: View {

    @State var camera: CameraModel

    /// 다이얼 높이 (버튼 줄은 이 영역의 아래쪽)
    static var height: CGFloat { 120 }
    /// 손가락을 이만큼(pt) 밀면 배율이 2배
    private let pointsPerDoubling: CGFloat = 70
    private let collapseDelay: Duration = .seconds(1.5)

    @State private var isDialShown = false
    @State private var dragStartFactor: CGFloat?
    @State private var collapseTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            if isDialShown {
                // 다이얼이 펼쳐지면 영역 전체에서 밀기를 받음
                withDialGestures(ZoomDial(zoom: camera.zoom).contentShape(.rect))
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            } else {
                // 접혀 있을 때는 버튼 줄만 터치를 받고, 나머지는 미리보기로 넘김
                withDialGestures(buttons)
                    .transition(.opacity)
            }
        }
        .frame(height: Self.height, alignment: .bottom)
        .sensoryFeedback(.selection, trigger: camera.zoom.activePreset)
        .animation(.easeOut(duration: 0.2), value: isDialShown)
    }

    private var buttons: some View {
        HStack(spacing: 2) {
            ForEach(camera.zoom.presets, id: \.self) { preset in
                presetButton(preset)
            }
        }
        .padding(3)
        .background(.black.opacity(0.3), in: .capsule)
        .contentShape(.capsule)
    }

    /// 좌우로 밀기 · 길게 누르기 → 다이얼
    private func withDialGestures<Content: View>(_ content: Content) -> some View {
        content
            .gesture(dialDrag)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    showDial()
                    scheduleCollapse()
                }
            )
    }

    private func presetButton(_ preset: CGFloat) -> some View {
        let isActive = camera.zoom.activePreset == preset
        // 현재 버튼에는 실제 배율 (예: 1.4×)
        let title = isActive ? ZoomState.label(camera.zoom.displayFactor) + "×" : ZoomState.label(preset)
        return Button {
            Task { await camera.setZoom(preset, animated: true) }
        } label: {
            Text(title)
                .font(.system(size: isActive ? 13 : 12, weight: .semibold))
                .foregroundStyle(isActive ? Color.cameraYellow : .white)
                .frame(width: isActive ? 38 : 30, height: isActive ? 38 : 30)
                .background(.black.opacity(isActive ? 0.55 : 0.35), in: .circle)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    private var dialDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                showDial()
                collapseTask?.cancel()
                let start = dragStartFactor ?? camera.zoom.displayFactor
                dragStartFactor = start
                // 왼쪽으로 밀면 확대 (다이얼 눈금이 왼쪽으로 돌아감)
                let factor = start * pow(2, -value.translation.width / pointsPerDoubling)
                Task { await camera.setZoom(factor, animated: false) }
            }
            .onEnded { _ in
                dragStartFactor = nil
                scheduleCollapse()
            }
    }

    private func showDial() {
        guard !isDialShown else { return }
        isDialShown = true
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(for: collapseDelay)
            guard !Task.isCancelled else { return }
            isDialShown = false
        }
    }
}

/// 왼쪽 아래 꽃 버튼. 접사 중이면 노란색, 누르면 자동 접사 전환을 끄고(빗금) 다시 누르면 켬
struct MacroButton<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        let isEnabled = camera.zoom.isAutoMacroEnabled
        Button {
            Task { await camera.setAutoMacroEnabled(!isEnabled) }
        } label: {
            Image(systemName: isEnabled ? "camera.macro" : "camera.macro.slash")
                .font(.system(size: 15))
                .foregroundStyle(isEnabled ? Color.cameraYellow : .white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.35), in: .circle)
        }
        .buttonStyle(.plain)
    }
}
