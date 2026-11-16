//
//  PreviewGestures.swift
//  포징
//
//  미리보기 자리의 터치 (CameraView에서 분리). 탭 초점, 길게 누르기 잠금, 밀기(밝기 · 투명도 · 모드), 두 손가락 확대
//

import SwiftUI
import AVFoundation

/// 미리보기 자리의 터치: 탭 초점, 길게 누르기 잠금, 밀기(밝기 · 투명도 · 모드), 두 손가락 확대.
/// 위치는 미리보기 자리 좌표이고, 카메라에 넘길 때만 층 좌표로 바꾼다
struct PreviewGestures<CameraModel: Camera>: ViewModifier {

    let camera: CameraModel
    let layers: LayerState
    let focus: FocusModel
    let layout: CameraLayout
    /// 분할 칸 보기에서 누른 자리를 원래 미리보기 자리로 바꿀 때 씀
    let split: SplitPreviewGeometry
    /// 좌우로 밀어 투명도를 바꾸는 중인 레이어 (화면에 값 표시)
    @Binding var opacityDragKind: LayerKind?
    /// 스타일 화면에서는 좌우로 밀면 모드 대신 스타일이 바뀜
    let onStyleSwipe: ((SwipeDirection) -> Void)?

    /// 길게 누르기 위치 (onLongPressGesture는 위치를 주지 않아 따로 기록)
    @State private var touchLocation: CGPoint = .zero
    /// 지금 미는 방향. 위아래 = 밝기, 좌우 = 모드 전환
    @State private var dragAxis: Axis?
    /// 두 손가락 확대를 시작할 때 배율
    @State private var pinchStartZoom: CGFloat?
    /// 투명도 밀기를 시작할 때 투명도 · 폰 방향 (도중에 폰을 돌려도 같은 방향 기준)
    @State private var opacityDragStart: Double?
    @State private var opacityDragAngle: Double?
    /// 레이어가 있을 때 노출 바 근처에서 시작한 밀기: 노출만 (투명도 · 모드 전환 없음)
    @State private var isExposureOnlyDrag = false
    /// 밀기가 취소되어 onEnded가 오지 않아도 상태를 비우기 위한 표시
    @GestureState private var isDragging = false
    /// 폰 방향. 투명도는 보는 사람 기준 좌우로 밀 때 바뀜 (가로로 돌리면 화면 위아래)
    @Environment(\.iconAngle) private var iconAngle

    func body(content: Content) -> some View {
        content
            // 탭 → 초점 · 노출 + 노란 사각형. 포즈 · MY 패널이 열려 있으면 같이 닫음
            .onTapGesture { location in
                layers.closePanel()
                focus.tap(at: location)
                let point = layout.previewLayerPoint(from: split.unprojected(location))
                Task { await camera.focusAndExpose(at: point) }
            }
            // 길게 누르기 → AE/AF 잠금
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                focus.lock(at: touchLocation)
                let point = layout.previewLayerPoint(from: split.unprojected(touchLocation))
                Task { await camera.lockFocusAndExposure(at: point) }
            }
            .simultaneousGesture(touchTracker)
            // 위아래로 밀면 밝기, 좌우로 밀면 모드 전환 (기본 카메라와 같은 방향)
            .simultaneousGesture(dragGesture)
            .onChange(of: isDragging) { _, isActive in
                if !isActive { resetDrag() }
            }
            // 두 손가락 벌리기/모으기 → 배율
            .simultaneousGesture(pinchGesture)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard camera.zoom.isAvailable else { return }
                let start = pinchStartZoom ?? camera.zoom.displayFactor
                pinchStartZoom = start
                Task { await camera.setZoom(start * value.magnification, animated: false) }
            }
            .onEnded { _ in
                pinchStartZoom = nil
            }
    }

    private var touchTracker: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchLocation = value.startLocation
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($isDragging) { _, isActive, _ in
                isActive = true
            }
            .onChanged { value in
                if dragAxis == nil {
                    dragAxis = abs(value.translation.height) > abs(value.translation.width) ? .vertical : .horizontal
                    isExposureOnlyDrag = onStyleSwipe == nil && layers.hasSelection
                        && focus.canAdjustBias(startingAt: value.startLocation)
                    startOpacityDragIfNeeded(value)
                }
                // 레이어 투명도 (노출과 섞이지 않게 여기서 끝)
                if let kind = opacityDragKind, let start = opacityDragStart {
                    let fraction = Double(viewerTranslation(value.translation).width / AppDefaults.opacityDragDistance)
                    layers.setOpacity(kind, from: start, dragged: fraction)
                    return
                }
                // 초점 표시(노출 바) 근처에서 시작한 위아래 밀기만 밝기 조절
                guard dragAxis == .vertical,
                      focus.canAdjustBias(startingAt: value.startLocation),
                      let bias = focus.adjustBias(byDragging: value.translation.height)
                else { return }
                Task { await camera.setExposureBias(bias) }
            }
            .onEnded { value in
                defer { resetDrag() }
                guard opacityDragKind == nil,
                      !isExposureOnlyDrag,
                      dragAxis == .horizontal,
                      abs(value.translation.width) >= 50,
                      !camera.captureActivity.isRecording
                else { return }
                let direction: SwipeDirection = value.translation.width < 0 ? .left : .right
                if let onStyleSwipe {
                    onStyleSwipe(direction)
                    return
                }
                camera.captureMode = CaptureModePicker<CameraModel>.mode(after: camera.captureMode, swipe: direction)
            }
    }

    /// 끝나거나 취소된 밀기의 상태 비우기
    private func resetDrag() {
        dragAxis = nil
        focus.endAdjusting()
        opacityDragKind = nil
        opacityDragStart = nil
        opacityDragAngle = nil
        isExposureOnlyDrag = false
    }

    /// 레이어가 선택되어 있고 보는 사람 기준 좌우로 밀기 시작하면 투명도 조절.
    /// 노출 바에서 시작한 밀기 · 스타일 화면은 제외
    private func startOpacityDragIfNeeded(_ value: DragGesture.Value) {
        guard onStyleSwipe == nil,
              !focus.canAdjustBias(startingAt: value.startLocation),
              let kind = layers.opacityDragTarget
        else { return }
        let viewer = viewerTranslation(value.translation)
        guard abs(viewer.width) > abs(viewer.height) else { return }
        opacityDragAngle = iconAngle
        opacityDragKind = kind
        opacityDragStart = layers[kind].opacity
    }

    /// 화면 좌표로 민 거리를 보는 사람 기준으로 (오른쪽 +, 아래 +)
    private func viewerTranslation(_ translation: CGSize) -> CGSize {
        let angle = (opacityDragAngle ?? iconAngle) * .pi / 180
        return CGSize(width: translation.width * cos(angle) + translation.height * sin(angle),
                      height: -translation.width * sin(angle) + translation.height * cos(angle))
    }
}
