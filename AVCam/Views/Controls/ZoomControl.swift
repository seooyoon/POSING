//
//  ZoomControl.swift
//  포징
//
//  배율 버튼 `.5 · 1 · 2 · 5` (docs/02_UI.md 6절). 가운데 고정 원 안에 현재 버튼이 노란 글씨 + `×`로 들어오고
//  줄이 좌우로 밀린다. 버튼 사이 배율이면 그 자리에 실제 값. 1×를 다시 누르면 24 → 28 → 35mm. 길게 누르거나 좌우로 밀면 다이얼이 펼쳐지고 손을 떼면 1.5초 뒤 접힌다.
//  카메라 컨트롤로 배율이 바뀔 때도 다이얼이 잠깐 보인다 (두 손가락 확대는 다이얼 없이).
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
    /// 버튼 가운데끼리 간격
    private let buttonSpacing: CGFloat = 39

    @State private var isDialShown = false
    @State private var dragStartFactor: CGFloat?
    @State private var collapseTask: Task<Void, Never>?
    /// 배율 버튼을 눌러 부드럽게 바뀌는 동안은 다이얼을 띄우지 않음
    @State private var presetZoomUntil = Date.distantPast
    /// 방금 누른 버튼. 배율이 따라오는 동안 중간 숫자 없이 이 버튼에 원을 표시
    @State private var tappedPreset: CGFloat?
    /// 마지막으로 버튼으로 요청한 배율
    @State private var requestedFactor: CGFloat?
    /// 1×를 누른 직후 원 안에 보이는 화각 (mm)
    @State private var millimeterBadge: Int?
    @State private var millimeterTask: Task<Void, Never>?
    /// 밀기 중 마지막으로 요청한 배율. 한 번에 하나씩, 가장 최근 값만 카메라에 보냄 (순서가 뒤섞이지 않게)
    @State private var pendingDragFactor: CGFloat?
    @State private var dragZoomTask: Task<Void, Never>?

    /// 원이 있는 버튼
    private var activePreset: CGFloat? { tappedPreset ?? camera.zoom.activePreset }

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
                        .transition(.opacity)
                }
            }
            // 제스처는 바뀌지 않는 바깥 뷰에 한 번만 붙임 (펼쳐지는 중에도 밀기가 끊기지 않게).
            // 배율 버튼 위에서 시작해도 버튼보다 밀기가 먼저 (탭은 움직임이 없어 그대로 버튼으로)
            .highPriorityGesture(dialDrag)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: AppDefaults.zoomDialLongPressDuration).onEnded { _ in
                    showDial()
                    scheduleCollapse()
                }
            )
            .sensoryFeedback(.selection, trigger: camera.zoom.activePreset)
            .animation(.easeOut(duration: 0.12), value: isDialShown)
            // 카메라 컨트롤로 배율이 바뀌면 다이얼 표시. 밀고 있는 동안은 prefersMinimizedUI가 켜짐
            // (두 손가락 확대 · 배율 버튼은 표시하지 않음)
            .onChange(of: camera.zoom.displayFactor) {
                guard camera.prefersMinimizedUI, dragStartFactor == nil, Date.now > presetZoomUntil else { return }
                showDial()
                scheduleCollapse()
            }
    }

    /// 원은 화면 가운데에 고정, 글자 줄이 밀려서 지금 버튼이 원 안으로 들어옴 (기본 카메라와 같음)
    private var buttons: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.55))
                .frame(width: 38, height: 38)
            HStack(spacing: 0) {
                ForEach(camera.zoom.presets, id: \.self) { preset in
                    presetButton(preset)
                }
            }
            .offset(x: rowOffset)
            .animation(.spring(duration: 0.25, bounce: 0), value: activePreset)
        }
        .contentShape(.rect)
    }

    /// 지금 버튼을 화면 가운데로 옮기는 거리
    private var rowOffset: CGFloat {
        let presets = camera.zoom.presets
        guard let active = activePreset, let index = presets.firstIndex(of: active) else { return 0 }
        return (CGFloat(presets.count - 1) / 2 - CGFloat(index)) * buttonSpacing
    }

    private func presetButton(_ preset: CGFloat) -> some View {
        let isActive = activePreset == preset
        return Button {
            tap(preset)
        } label: {
            Group {
                if isActive, let millimeterBadge {
                    // 1×를 누르면 잠깐 화각 표시
                    VStack(spacing: -2) {
                        Text(verbatim: "\(millimeterBadge)").font(.cameraDigits(size: 15, weight: .semibold))
                        Text(verbatim: "MM").font(.system(size: 9, weight: .semibold))
                    }
                } else if isActive {
                    // 현재 버튼에는 실제 배율 (예: 1.4×). 버튼을 눌렀을 때는 중간 숫자 없이 버튼 값
                    let value = tappedPreset == nil ? camera.zoom.displayFactor : preset
                    HStack(spacing: 0) {
                        Text(verbatim: ZoomState.activeLabel(value)).font(.cameraDigits(size: 15))
                        Text(verbatim: "×").font(.system(size: 13))
                    }
                } else {
                    Text(verbatim: ZoomState.label(preset)).font(.system(size: 15))
                }
            }
            .foregroundStyle(isActive ? Color.cameraYellow : .white)
            .frame(width: buttonSpacing, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func tap(_ preset: CGFloat) {
        // 꾹 눌러 다이얼을 연 뒤 손을 뗄 때는 버튼 배율로 바꾸지 않음
        guard !isDialShown else { return }
        // 이미 1×면 24 → 28 → 35mm로 돌아감
        // 빠르게 연달아 누르면 카메라 값이 아직 안 바뀌었을 수 있어 방금 요청한 값을 기준으로 함
        let current = currentFactor
        let target = preset == 1 && activePreset == 1 ? ZoomState.nextMainLensFactor(after: current) : preset
        requestedFactor = target
        presetZoomUntil = .now + 0.8
        tappedPreset = preset
        showMillimeters(preset == 1 ? ZoomState.millimeters(target) : nil)
        Task {
            // 기본 카메라처럼 배율을 바로 바꿈
            await camera.setZoom(target, animated: false)
            try? await Task.sleep(for: .seconds(0.25))
            if tappedPreset == preset { tappedPreset = nil }
        }
    }

    /// mm 표시를 잠깐 보이고 배율 글자로 돌아감
    private func showMillimeters(_ value: Int?) {
        millimeterTask?.cancel()
        millimeterBadge = value
        guard value != nil else { return }
        millimeterTask = Task {
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { millimeterBadge = nil }
        }
    }

    private var dialDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                showDial()
                collapseTask?.cancel()
                let start = dragStartFactor ?? currentFactor
                dragStartFactor = start
                // 왼쪽으로 밀면 확대 (다이얼 눈금이 왼쪽으로 돌아감)
                let factor = start * pow(2, -value.translation.width / pointsPerDoubling)
                requestDragZoom(factor)
            }
            .onEnded { _ in
                dragStartFactor = nil
                scheduleCollapse()
            }
    }

    /// 지금 배율. 버튼을 막 누른 직후에는 카메라 값이 아직 따라오는 중이라 요청한 값을 씀
    private var currentFactor: CGFloat {
        Date.now < presetZoomUntil ? (requestedFactor ?? camera.zoom.displayFactor) : camera.zoom.displayFactor
    }

    private func requestDragZoom(_ factor: CGFloat) {
        pendingDragFactor = factor
        guard dragZoomTask == nil else { return }
        dragZoomTask = Task {
            while let target = pendingDragFactor {
                pendingDragFactor = nil
                await camera.setZoom(target, animated: false)
            }
            dragZoomTask = nil
        }
    }

    private func showDial() {
        guard !isDialShown else { return }
        showMillimeters(nil)
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
