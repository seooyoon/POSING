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
    /// 화면 어디든 탭한 자리 (열린 목록 닫기용, 탭은 가로막지 않음)
    @State private var screenTap: ScreenTap?
    /// 미리보기를 밀어 투명도를 바꾸는 중인 레이어
    @State private var opacityDragKind: LayerKind?
    var body: some View {
        GeometryReader { proxy in
            let layout = CameraLayout(proxy: proxy, captureMode: camera.captureMode, photoAspect: camera.photoAspect)
            // 분할 표시는 사진 모드에서만 (비디오는 항상 원래 비율)
            let isSplitShown = camera.captureMode == .photo
            let split = SplitPreviewGeometry(split: camera.splitShot, previewSize: layout.previewRect.size,
                                             isEnabled: isSplitShown)
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
                        // 분할 칸 보기: 지금 칸으로 줄여 옮김
                        .modifier(SplitCellTransform(geometry: split))
                    }
                    // 자르지 않음: 1:1이면 4:3 영상의 위아래가 바깥에 이어서 비침 (OutsidePreviewDim이 어둡게)
                    .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                    .contentShape(previewTouchArea(in: layout), eoFill: true)
                    .modifier(PreviewGestures(camera: camera, layers: layers, focus: focus, layout: layout, split: split,
                                              opacityDragKind: $opacityDragKind,
                                              onStyleSwipe: isShowingStyleScreen ? { styles.step(by: $0 == .left ? 1 : -1) } : nil))
                    // 분할 칸 보기 중에는 미리보기 자리로 자름 (1:1 · 16:9에서 바깥 4:3 부분이 비치지 않게)
                    .modifier(StyleCardEffect(isActive: isShowingStyleScreen, layout: layout, clipsOutside: split.isShowing))
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
                    // 분할 칸 보기에서는 레이어도 미리보기와 함께 지금 칸으로, 격자 · 중심점 · 수평계는 지금 칸에 꼭 맞게
                    LayerOverlay(layers: layers)
                        .modifier(SplitCellTransform(geometry: split))
                    GridOverlay()
                        .modifier(SplitCellTransform(geometry: split, fitsCrop: true))
                    LevelOverlay(level: level)
                        .modifier(SplitCellTransform(geometry: split, fitsCrop: true))
                    // 분할: 나머지 칸 (찍은 사진 · 번호, 누르면 그 칸 찍기). 초점 아래
                    SplitPreviewOverlay(geometry: split)
                    FocusOverlay(focus: focus,
                                 topInset: max(0, layout.safeTop + CameraLayout.topBarHeight - layout.previewRect.minY))
                    OpacityDragLabel(layers: layers, kind: opacityDragKind,
                                     topInset: max(0, layout.safeTop + CameraLayout.topBarHeight - layout.previewRect.minY))
                }
                .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                .clipped()
                .modifier(StyleCardEffect(isActive: isShowingStyleScreen, layout: layout))
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                .animation(.easeInOut(duration: 0.25), value: camera.photoAspect)
                // 카메라 화면 UI
                CameraUI(camera: camera, layers: layers, looks: looks, styles: styles,
                         isShowingStyleScreen: $isShowingStyleScreen, layout: layout, screenTap: screenTap)
            }
            .coordinateSpace(.named(CameraView.screenSpace))
            // 버튼 · 미리보기 탭과 함께 인식 (목록이 열려 있어도 누른 것이 바로 동작하고 목록은 닫힘)
            .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named(CameraView.screenSpace)).onEnded { value in
                screenTap = ScreenTap(id: (screenTap?.id ?? 0) + 1, location: value.location)
            })
            .ignoresSafeArea()
            // 폰을 가로로 돌리면 아이콘 · 글자만 돌아감 (docs/02_UI.md 10절)
            .environment(\.iconAngle, level.iconAngle)
            // 카메라 화면만 다크 고정. 설정 화면 · 사진 피커는 아이폰 설정을 따름 (docs/02_UI.md 10절)
            .environment(\.colorScheme, .dark)
        }
        // 모드 · 카메라가 바뀌면 초점 표시를 지움
        .onChange(of: camera.captureMode) { focus.clear() }
        .onChange(of: camera.isSwitchingVideoDevices) { _, isSwitching in
            focus.clear()
            frozenSeeThrough = isSwitching ? liveSeeThrough : nil
        }
        // MY 패키지 대표 이미지 꾹 누르기 → 그 패키지에 사진 추가
        .myPhotoPicker(packageID: $layers.pickingMYPackageID, layers: layers)
        // 설정 버튼 → 설정 화면
        .fullScreenCover(isPresented: $layers.isShowingSettings) {
            SettingsView(layers: layers, looks: looks)
        }
    }

    private static var screenSpace: String { "cameraScreen" }

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
            // 카드로 보이는 부분만 (1:1은 좌우가 잘림)
            let clip = card.clipSize
            var path = Path(CGRect(x: (rect.width - clip.width) / 2, y: (rect.height - clip.height) / 2,
                                   width: clip.width, height: clip.height))
            if card.isShutterInsideCard {
                let side = 100 / card.scale
                let shutterY = (card.shutterCenterY - card.cardRect.midY) / card.scale + rect.height / 2
                path.addRect(CGRect(x: rect.width / 2 - side / 2, y: shutterY - side / 2, width: side, height: side))
            }
            return path
        }
        let top = max(rect.minY, layout.safeTop + CameraLayout.topBarHeight)
        var path = Path(CGRect(x: 0, y: top - rect.minY, width: rect.width, height: max(0, rect.maxY - top)))
        // 셔터 자리 (eoFill로 구멍)
        path.addRect(CGRect(x: layout.centerX - 50 - rect.minX, y: layout.shutterCenterY - 50 - rect.minY,
                            width: 100, height: 100))
        // 카메라 버튼 · 분할 버튼 자리 (사진 모드에서만 보이고, 카메라 컨트롤을 밀고 있는 동안은 숨음)
        if camera.captureMode == .photo && !camera.prefersMinimizedUI {
            for centerX in [CameraLayout.cameraButtonCenterX, layout.size.width - CameraLayout.cameraButtonCenterX] {
                path.addRect(CGRect(x: centerX - CameraLookList.cellSize / 2 - rect.minX,
                                    y: layout.shutterCenterY - CameraLookList.cellSize / 2 - rect.minY,
                                    width: CameraLookList.cellSize, height: CameraLookList.cellSize))
            }
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

/// 미리보기 자리의 터치: 탭 초점, 길게 누르기 잠금, 밀기(밝기 · 투명도 · 모드), 두 손가락 확대.
/// 위치는 미리보기 자리 좌표이고, 카메라에 넘길 때만 층 좌표로 바꾼다
private struct PreviewGestures<CameraModel: Camera>: ViewModifier {

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

/// 스타일 화면: 미리보기가 둥근 카드로 줄어듦. 아니면 원래 미리보기 자리.
/// clipsOutside가 false면 평소에는 자리 바깥도 그대로 보임 (카드로 바뀔 때만 잘림)
private struct StyleCardEffect: ViewModifier {

    let isActive: Bool
    let layout: CameraLayout
    var clipsOutside = true

    func body(content: Content) -> some View {
        let card = StyleScreenLayout(layout: layout)
        let scale = isActive ? card.scale : 1
        // 카드일 때는 카드로 보이는 크기(1:1은 좌우가 잘림). 평소에는 자리 그대로이거나,
        // 자르지 않을 때는 화면보다 크게 넓혀 자르지 않은 것처럼 (카드로 바뀔 때 부드럽게 좁아짐)
        let preview = layout.previewRect.size
        let huge = max(layout.size.width, layout.size.height) * 3
        let clip = isActive ? card.clipSize : (clipsOutside ? preview : CGSize(width: huge, height: huge))
        content
            .clipShape(CenteredRoundedRect(size: clip,
                                           cornerRadius: isActive ? StyleScreenLayout.cardCornerRadius / scale : 0))
            .scaleEffect(scale)
            .position(x: layout.previewRect.midX,
                      y: isActive ? card.cardRect.midY : layout.previewRect.midY)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: isActive)
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}

/// 가운데를 기준으로 정한 크기만큼 남기는 둥근 사각형 (크기 · 모서리가 부드럽게 바뀜)
private struct CenteredRoundedRect: Shape {

    var size: CGSize
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(size.width, size.height), cornerRadius) }
        set {
            size = CGSize(width: newValue.first.first, height: newValue.first.second)
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let frame = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                           width: size.width, height: size.height)
        return Path(roundedRect: frame, cornerRadius: cornerRadius, style: .continuous)
    }
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
