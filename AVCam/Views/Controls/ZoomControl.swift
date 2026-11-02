//
//  ZoomControl.swift
//  포징
//
//  배율 버튼 `.5 · 1 · 2 · 5` (docs/02_UI.md 6절). 현재 버튼만 어두운 원 + 노란 글씨 + `×`,
//  버튼 사이 배율이면 그 자리에 실제 값. 길게 누르거나 좌우로 밀면 다이얼이 펼쳐지고 손을 떼면 1.5초 뒤 접힌다.
//  두 손가락 확대 · 카메라 컨트롤로 배율이 바뀔 때도 다이얼이 잠깐 보인다.
//

import SwiftUI

struct ZoomControl<CameraModel: Camera>: View {

    @State var camera: CameraModel
    /// 다이얼 원의 반지름
    let dialRadius: CGFloat
    /// 버튼 줄 가운데 ~ 다이얼 원 가운데 (아래로). 원이 셔터 뒤 하단 영역을 덮음
    let dialCenterBelowRow: CGFloat

    /// 버튼 영역 높이 (버튼 줄은 이 영역의 아래쪽)
    static var height: CGFloat { 120 }
    /// 영역 아래 끝 ~ 버튼 줄 가운데 (CameraUI 배치와 같음)
    static var rowCenterAboveBottom: CGFloat { 20 }
    private let collapseDelay: Duration = .seconds(1.5)

    @State private var isDialShown = false
    @State private var dragStartFactor: CGFloat?
    @State private var collapseTask: Task<Void, Never>?
    /// 배율 버튼을 눌러 부드럽게 바뀌는 동안은 다이얼을 띄우지 않음
    @State private var presetZoomUntil = Date.distantPast

    /// 손가락을 이만큼(pt) 밀면 배율이 2배. 눈금이 손가락을 따라가도록 원 둘레 기준
    private var pointsPerDoubling: CGFloat {
        dialRadius * ZoomDial.degreesPerDoubling * .pi / 180
    }

    var body: some View {
        buttons
            .opacity(isDialShown ? 0 : 1)
            .frame(height: Self.height, alignment: .bottom)
            .overlay(alignment: .bottom) {
                if isDialShown {
                    // 다이얼이 펼쳐지면 원 전체에서 밀기를 받음 (셔터 · 하단 줄은 위에 있어 그대로 눌림)
                    ZoomDial(zoom: camera.zoom)
                        .frame(width: dialRadius * 2, height: dialRadius * 2)
                        .contentShape(.circle)
                        .offset(y: dialCenterBelowRow - Self.rowCenterAboveBottom + dialRadius)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            // 제스처는 바뀌지 않는 바깥 뷰에 한 번만 붙임 (펼쳐지는 중에도 밀기가 끊기지 않게)
            .gesture(dialDrag)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: AppDefaults.zoomDialLongPressDuration).onEnded { _ in
                    showDial()
                    scheduleCollapse()
                }
            )
            .sensoryFeedback(.selection, trigger: camera.zoom.activePreset)
            .animation(.easeOut(duration: 0.2), value: isDialShown)
            // 두 손가락 확대 · 카메라 컨트롤로 배율이 바뀌어도 다이얼 표시 (배율 버튼은 제외)
            .onChange(of: camera.zoom.displayFactor) {
                guard dragStartFactor == nil, Date.now > presetZoomUntil else { return }
                showDial()
                scheduleCollapse()
            }
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

    private func presetButton(_ preset: CGFloat) -> some View {
        let isActive = camera.zoom.activePreset == preset
        // 현재 버튼에는 실제 배율 (예: 1.4×)
        let title = isActive ? ZoomState.label(camera.zoom.displayFactor) + "×" : ZoomState.label(preset)
        return Button {
            // 꾹 눌러 다이얼을 연 뒤 손을 뗄 때는 버튼 배율로 바꾸지 않음
            guard !isDialShown else { return }
            presetZoomUntil = .now + 0.8
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

/// 전면 카메라 화각 버튼: 가깝게일 때 바깥 화살표(누르면 넓게), 넓게일 때 안쪽 화살표
struct FrontFieldOfViewButton<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        let isWide = camera.zoom.isFrontWide
        Button {
            Task { await camera.setFrontWide(!isWide) }
        } label: {
            Image(systemName: isWide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.4), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("전면 화각")
        .accessibilityValue(isWide ? "넓게" : "가깝게")
        .sensoryFeedback(.selection, trigger: isWide)
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
