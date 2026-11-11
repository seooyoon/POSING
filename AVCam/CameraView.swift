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
    @State private var styles = StyleState()
    @State private var isShowingStyleScreen = false
    @State private var focus = FocusModel()
    @State private var level = LevelModel()
    /// 렌즈를 바꾸는 동안 고정해 둘 바깥 비침 상태 (바꾸는 순간 배율 값이 흔들려 미리보기 길이가 출렁이지 않게)
    @State private var frozenSeeThrough: Bool?
    var body: some View {
        GeometryReader { proxy in
            let layout = CameraLayout(proxy: proxy, captureMode: camera.captureMode, photoAspect: camera.photoAspect)
            ZStack(alignment: .topLeading) {
                // 카메라 화면은 다크 고정 (docs/02_UI.md 10절). 미리보기 바깥은 검정이고,
                // 1:1 · 16:9에서 잘려 나가는 4:3 부분만 미리보기와 같은 크기로 어둡게 비침 (docs/02_UI.md 5절)
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
                    // 자르지 않음: 1:1이면 4:3 영상의 위아래가 바깥에 이어서 비침 (OutsidePreviewDim이 어둡게)
                    .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                    .contentShape(previewTouchArea(in: layout), eoFill: true)
                    .modifier(PreviewGestures(camera: camera, layers: layers, focus: focus, layout: layout,
                                              onStyleSwipe: isShowingStyleScreen ? { styles.step(by: $0 == .left ? 1 : -1) } : nil))
                    .modifier(StyleCardEffect(isActive: isShowingStyleScreen, layout: layout, clipsOutside: false))
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                OutsidePreviewDim(previewRect: layout.previewRect, isSeeThrough: isOutsideSeeThrough)
                    .opacity(isShowingStyleScreen ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25), value: isOutsideSeeThrough)
                    .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                    .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                    .animation(.spring(duration: 0.35, bounce: 0.1), value: isShowingStyleScreen)
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
                .modifier(StyleCardEffect(isActive: isShowingStyleScreen, layout: layout))
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                // 카메라 화면 UI
                CameraUI(camera: camera, layers: layers, looks: looks, styles: styles,
                         isShowingStyleScreen: $isShowingStyleScreen, layout: layout)
            }
            .ignoresSafeArea()
            // 카메라 화면만 다크 고정. 설정 화면 · 사진 피커는 아이폰 설정을 따름 (docs/02_UI.md 10절)
            .environment(\.colorScheme, .dark)
        }
        // 모드 · 카메라가 바뀌면 초점 표시를 지움
        .onChange(of: camera.captureMode) { focus.clear() }
        .onChange(of: camera.isSwitchingVideoDevices) { _, isSwitching in
            focus.clear()
            frozenSeeThrough = isSwitching ? liveSeeThrough : nil
        }
        // MY 꾹 누르기 → 사진 고르기
        .myPhotoPicker(isPresented: $layers.isPickingMY, layers: layers)
        // 초기화 꾹 누르기 → 설정 화면
        .fullScreenCover(isPresented: $layers.isShowingSettings) {
            SettingsView(layers: layers, looks: looks)
        }
    }

    /// 1:1 · 16:9에서 잘려 나가는 4:3 부분이 비치는지. 기본 카메라처럼 0.5× · 접사 · 전면 · 비디오 계열은 검정
    private var isOutsideSeeThrough: Bool {
        frozenSeeThrough ?? liveSeeThrough
    }

    private var liveSeeThrough: Bool {
        camera.captureMode == .photo && !camera.zoom.isFrontCamera
            && camera.zoom.displayFactor >= 0.99 && !camera.zoom.isMacroActive
    }

    /// 미리보기에서 터치를 받는 영역 (미리보기 기준 좌표): 상단 바 아래부터, 셔터 자리는 뺌.
    /// 16:9 · 비디오는 미리보기가 상단 바 · 셔터 뒤까지 올라가므로, 미리보기 제스처가 버튼 터치를 가져가지 않게 함
    private func previewTouchArea(in layout: CameraLayout) -> Path {
        let rect = layout.previewRect
        // 스타일 화면: 카드 전체가 터치 영역이고, 카드 안으로 올라온 셔터 자리만 뺌 (줄이기 전 좌표로)
        if isShowingStyleScreen {
            let card = StyleScreenLayout(layout: layout)
            let side = 100 / card.scale
            let shutterY = (card.shutterCenterY - card.cardRect.midY) / card.scale + rect.height / 2
            var path = Path(CGRect(origin: .zero, size: rect.size))
            path.addRect(CGRect(x: rect.width / 2 - side / 2, y: shutterY - side / 2, width: side, height: side))
            return path
        }
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
    /// 스타일 화면에서는 좌우로 밀면 모드 대신 스타일이 바뀜
    let onStyleSwipe: ((SwipeDirection) -> Void)?

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
                if let onStyleSwipe {
                    onStyleSwipe(direction)
                    return
                }
                camera.captureMode = CaptureModePicker<CameraModel>.mode(after: camera.captureMode, swipe: direction)
            }
    }
}

/// 스타일 화면: 미리보기가 둥근 카드로 줄어듦. 아니면 원래 미리보기 자리.
/// clipsOutside가 false면 평소에는 자리 바깥도 그대로 보임 (카드로 바뀔 때만 잘림)
private struct StyleCardEffect: ViewModifier {

    let isActive: Bool
    let layout: CameraLayout
    var clipsOutside = true

    func body(content: Content) -> some View {
        let card = StyleScreenLayout(layout: layout)
        let scale = isActive ? card.scale : 1
        // 평소에는 자르는 모양을 화면보다 크게 넓혀 자르지 않은 것처럼 (카드로 줄어들 때 부드럽게 좁아짐)
        let outset: CGFloat = isActive || clipsOutside ? 0 : -max(layout.size.width, layout.size.height)
        content
            .clipShape(RoundedRectangle(cornerRadius: isActive ? StyleScreenLayout.cardCornerRadius / scale : 0, style: .continuous)
                .inset(by: outset))
            .scaleEffect(scale)
            .position(x: layout.previewRect.midX,
                      y: isActive ? card.cardRect.midY : layout.previewRect.midY)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: isActive)
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
