/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

@MainActor
struct CameraView<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @State private var layers = LayerState()
    @State private var looks = CameraLookState()
    @State private var focus = FocusModel()
    @State private var level = LevelModel()
    var body: some View {
        GeometryReader { proxy in
            let layout = CameraLayout(proxy: proxy, captureMode: camera.captureMode, photoAspect: camera.photoAspect)
            ZStack(alignment: .topLeading) {
                // 카메라 화면은 다크 고정 (docs/02_UI.md 10절)
                Color.black
                // 미리보기는 모드에 맞는 자리 · 비율로 (사진 4:3, 비디오 16:9)
                // 비율을 바꿀 때 층 크기는 그대로 두고 확대 · 자르기만 움직임 (영상이 흔들리지 않게)
                Color.clear
                    .overlay {
                        PreviewContainer(camera: camera) {
                            preview
                        }
                        .frame(width: layout.previewLayerSize.width, height: layout.previewLayerSize.height)
                        .scaleEffect(layout.previewScale)
                    }
                    .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                    .clipped()
                    .contentShape(previewTouchArea(in: layout), eoFill: true)
                    .modifier(PreviewGestures(camera: camera, layers: layers, focus: focus, layout: layout))
                    .position(x: layout.previewRect.midX, y: layout.previewRect.midY)
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                // 미리보기 위 표시 (아래 → 위): MY · 포즈 레이어 → 격자 · 중심점 → 수평계 · 초점 (docs/02_UI.md 5절)
                // 모두 화면에만 그리고 저장본에는 없음
                Group {
                    LayerOverlay(layers: layers)
                    GridOverlay()
                    LevelOverlay(level: level)
                    FocusOverlay(focus: focus,
                                 topInset: max(0, layout.safeTop + CameraLayout.topBarHeight - layout.previewRect.minY))
                }
                .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                .clipped()
                .position(x: layout.previewRect.midX, y: layout.previewRect.midY)
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                // 카메라 화면 UI
                CameraUI(camera: camera, layers: layers, looks: looks, layout: layout)
            }
            .ignoresSafeArea()
            // 카메라 화면만 다크 고정. 설정 화면 · 사진 피커는 아이폰 설정을 따름 (docs/02_UI.md 10절)
            .environment(\.colorScheme, .dark)
        }
        // 모드 · 카메라가 바뀌면 초점 표시를 지움
        .onChange(of: camera.captureMode) { focus.clear() }
        .onChange(of: camera.isSwitchingVideoDevices) { focus.clear() }
        // MY 꾹 누르기 → 사진 고르기
        .myPhotoPicker(isPresented: $layers.isPickingMY, layers: layers)
        // 초기화 꾹 누르기 → 설정 화면
        .fullScreenCover(isPresented: $layers.isShowingSettings) {
            SettingsView(layers: layers, looks: looks)
        }
    }

    /// 미리보기에서 터치를 받는 영역 (미리보기 기준 좌표): 상단 바 아래부터, 셔터 자리는 뺌.
    /// 16:9 · 비디오는 미리보기가 상단 바 · 셔터 뒤까지 올라가므로, 미리보기 제스처가 버튼 터치를 가져가지 않게 함
    private func previewTouchArea(in layout: CameraLayout) -> Path {
        let rect = layout.previewRect
        let top = max(rect.minY, layout.safeTop + CameraLayout.topBarHeight)
        var path = Path(CGRect(x: 0, y: top - rect.minY, width: rect.width, height: max(0, rect.maxY - top)))
        // 셔터 자리 (eoFill로 구멍)
        path.addRect(CGRect(x: layout.centerX - 50 - rect.minX, y: layout.shutterCenterY - 50 - rect.minY,
                            width: 100, height: 100))
        // 카메라 버튼 자리 (사진 모드에서만 보이고, 카메라 컨트롤을 밀고 있는 동안은 숨음)
        if camera.captureMode == .photo && !camera.prefersMinimizedUI {
            path.addRect(CGRect(x: CameraLayout.cameraButtonCenterX - CameraLookList.cellSize / 2 - rect.minX,
                                y: layout.shutterCenterY - CameraLookList.cellSize / 2 - rect.minY,
                                width: CameraLookList.cellSize, height: CameraLookList.cellSize))
        }
        return path
    }

    /// A view that provides a preview of the captured content.
    private var preview: some View {
        CameraPreview(source: camera.previewSource)
            // Handle capture events from device hardware buttons.
            .onCameraCaptureEvent(defaultSoundDisabled: true) { event in
                if event.phase == .ended {
                    let sound: AVCaptureEventSound
                    switch camera.captureMode {
                    case .photo:
                        sound = .cameraShutter
                        // 카메라 컨트롤 · 음량 버튼도 셔터와 같이 타이머를 따름
                        await camera.shutterPressed()
                    case .video, .slowMotion, .timelapse:
                        sound = camera.captureActivity.isRecording ?
                            .endVideoRecording : .beginVideoRecording
                        // Toggle video recording when pressing a hardware button.
                        await camera.toggleRecording()
                    }
                    // Play a sound when capturing by clicking an AirPods stem.
                    if event.shouldPlaySound {
                        event.play(sound)
                    }
                }
            }
            /// The value of `shouldFlashScreen` changes briefly to `true` when capture
            /// starts, and then immediately changes to `false`. Use this change to
            /// flash the screen to provide visual feedback when capturing photos.
            .opacity(camera.shouldFlashScreen ? 0 : 1)
    }
}

/// 미리보기 자리의 터치: 탭 초점, 길게 누르기 잠금, 밀기(밝기 · 모드), 두 손가락 확대.
/// 위치는 미리보기 자리 좌표이고, 카메라에 넘길 때만 층 좌표로 바꾼다
private struct PreviewGestures<CameraModel: Camera>: ViewModifier {

    let camera: CameraModel
    let layers: LayerState
    let focus: FocusModel
    let layout: CameraLayout

    /// 길게 누르기 위치 (onLongPressGesture는 위치를 주지 않아 따로 기록)
    @State private var touchLocation: CGPoint = .zero
    /// 지금 미는 방향. 위아래 = 밝기, 좌우 = 모드 전환
    @State private var dragAxis: Axis?
    /// 두 손가락 확대를 시작할 때 배율
    @State private var pinchStartZoom: CGFloat?

    func body(content: Content) -> some View {
        content
            // 탭 → 초점 · 노출 + 노란 사각형. 포즈 · MY 패널이 열려 있으면 같이 닫음
            .onTapGesture { location in
                layers.closePanel()
                focus.tap(at: location)
                let point = layout.previewLayerPoint(from: location)
                Task { await camera.focusAndExpose(at: point) }
            }
            // 길게 누르기 → AE/AF 잠금
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                focus.lock(at: touchLocation)
                let point = layout.previewLayerPoint(from: touchLocation)
                Task { await camera.lockFocusAndExposure(at: point) }
            }
            .simultaneousGesture(touchTracker)
            // 위아래로 밀면 밝기, 좌우로 밀면 모드 전환 (기본 카메라와 같은 방향)
            .simultaneousGesture(dragGesture)
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
            .onChanged { value in
                if dragAxis == nil {
                    dragAxis = abs(value.translation.height) > abs(value.translation.width) ? .vertical : .horizontal
                }
                // 초점 표시 근처에서 시작한 위아래 밀기만 밝기 조절
                guard dragAxis == .vertical,
                      focus.canAdjustBias(startingAt: value.startLocation),
                      let bias = focus.adjustBias(byDragging: value.translation.height)
                else { return }
                Task { await camera.setExposureBias(bias) }
            }
            .onEnded { value in
                defer {
                    dragAxis = nil
                    focus.endAdjusting()
                }
                guard dragAxis == .horizontal,
                      abs(value.translation.width) >= 50,
                      !camera.captureActivity.isRecording
                else { return }
                let direction: SwipeDirection = value.translation.width < 0 ? .left : .right
                camera.captureMode = CaptureModePicker<CameraModel>.mode(after: camera.captureMode, swipe: direction)
            }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
