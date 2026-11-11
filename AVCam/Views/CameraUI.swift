/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents the main camera user interface.
*/

import SwiftUI

/// 카메라 화면 UI. 기본 카메라와 같은 자리에 상단 바 · 셔터 · 하단 줄을 놓는다.
struct CameraUI<CameraModel: Camera>: View {

    @State var camera: CameraModel
    let layers: LayerState
    let looks: CameraLookState
    let styles: StyleState
    @Binding var isShowingStyleScreen: Bool
    let layout: CameraLayout

    @State private var panelHeight: CGFloat = 0
    @State private var isShowingMoreMenu = false
    @State private var isShowingCameraList = false
    /// 카메라 버튼을 밀어서 고르는 중인 칸
    @State private var highlightedLookID: String?
    /// 상단 빠른 설정 판 (형식 버튼 · 오른쪽 묶음 꾹 누르기)
    @State private var quickSettings: QuickSettingsKind?
    /// LIVE를 켜고 끈 직후 잠깐 보이는 표시 (true = LIVE, false = LIVE 끔)
    @State private var liveNotice: Bool?
    @State private var liveNoticeTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            TopBar(camera: camera, layers: layers, isShowingMoreMenu: $isShowingMoreMenu, quickSettings: $quickSettings)
                .frame(width: layout.size.width)
                .position(x: layout.centerX, y: layout.topBarCenterY)
                // 빠른 설정 판 · 더보기 메뉴 · 스타일 화면이 열리면 사라짐 (기본 카메라와 같음)
                .opacity(isTopBarHidden ? 0 : 1)
                .allowsHitTesting(!isTopBarHidden)
                .blur(radius: isTopBarHidden ? 6 : 0)

            // 스타일 아이콘: 기본 카메라처럼 맨 위 줄 다이내믹 아일랜드 오른쪽. 사진 모드면 표준에서도 항상 보임
            if isShowingStyleIcon {
                Button {
                    quickSettings = nil
                    isShowingMoreMenu = false
                    isShowingStyleScreen.toggle()
                } label: {
                    StyleIcon(size: AppDefaults.statusStyleIconSize)
                        // 표준이 아닌 스타일을 쓰는 중이면 노란색
                        .foregroundStyle(camera.photoStyle.changesImage ? Color.cameraYellow : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스타일")
                .position(x: layout.size.width - AppDefaults.statusStyleIconTrailing, y: layout.safeTop / 2 + AppDefaults.statusStyleIconBelowCenter)
                .transition(.opacity)
                // 더보기 메뉴 · 빠른 설정 판의 바깥 탭 닫기 영역보다 위에 둬서, 열려 있어도 바로 스타일 화면으로
                .zIndex(1)
            }

            // 포즈 · MY 패널: 상단 바 바로 아래, 한 번에 하나만. 전환할 때는 내용만 바뀜
            if let kind = layers.openPanel {
                LayerPanel(layers: layers, kind: kind)
                    .frame(width: layout.size.width)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                    .offset(y: layout.safeTop + CameraLayout.topBarHeight)
                    .transition(.offset(y: -12).combined(with: .opacity))
            }

            // LIVE를 켜고 끄거나 LIVE 사진을 찍는 순간 미리보기 위쪽 가운데에 표시
            LiveBadge(isOn: liveNotice ?? true)
                .opacity(isShowingLiveBadge ? 1 : 0)
                .allowsHitTesting(false)
                .position(x: layout.centerX, y: previewTopY + 24)

            // 렌즈가 더러우면 미리보기 위쪽 가운데에 안내 (기본 카메라와 같은 자리).
            // 패널이 열리면 패널 바로 아래로, LIVE 표시가 뜨는 동안은 잠깐 숨김
            LensSmudgeBanner(isSmudged: camera.isLensSmudged)
                .opacity(isShowingLiveBadge ? 0 : 1)
                .position(x: layout.centerX, y: smudgeBannerCenterY)

            // 배율 버튼 · 다이얼 (다이얼 원은 셔터 · 하단 줄 뒤까지 펼쳐짐). 더보기 메뉴가 열리면 메뉴 뒤로 숨김
            if camera.zoom.isAvailable && !isShowingMoreMenu && !isShowingStyleScreen {
                ZoomControl(camera: camera,
                            dialRadius: CameraLayout.zoomDialRadius,
                            dialCenterBelowRow: layout.shutterCenterY + CameraLayout.zoomDialCenterBelowShutter - layout.zoomRowCenterY)
                    .frame(width: layout.size.width)
                    .position(x: layout.centerX, y: layout.zoomRowCenterY + ZoomControl<CameraModel>.rowCenterAboveBottom - ZoomControl<CameraModel>.height / 2)
            }
            // 전면 카메라는 배율 버튼 자리에 화각 버튼
            if camera.zoom.isFrontCamera && !isShowingMoreMenu && !isShowingStyleScreen {
                FrontFieldOfViewButton(camera: camera)
                    .position(x: layout.centerX, y: layout.zoomRowCenterY)
            }
            // 접사 중이거나 접사 전환을 꺼 두면 왼쪽 아래 꽃 버튼
            if camera.zoom.showsMacroButton && !isShowingMoreMenu && !isShowingStyleScreen {
                MacroButton(camera: camera)
                    .position(x: CameraLayout.sideInset + 22, y: layout.zoomRowCenterY)
                    // 기본 카메라처럼 서서히 나타나고 사라짐
                    .transition(.opacity)
            }

            // 더보기 메뉴가 열리면 셔터 · 하단 줄은 메뉴 속으로 사라짐
            // 스타일 화면: 카드 위아래 표시 · 패드 · 닫기 버튼
            if isShowingStyleScreen {
                StyleScreenControls(styles: styles, layout: layout) {
                    isShowingStyleScreen = false
                }
                .transition(.opacity)
            }

            Group {
                // 스타일 화면에서는 셔터가 카드 아래쪽 안으로 올라옴
                CaptureButton(camera: camera)
                    .position(x: layout.centerX,
                              y: isShowingStyleScreen ? StyleScreenLayout(layout: layout).shutterCenterY : layout.shutterCenterY)

                // 하단 줄은 스타일 화면에서 숨김
                BottomBar(camera: camera)
                    .frame(width: layout.size.width)
                    .position(x: layout.centerX, y: layout.bottomRowCenterY)
                    .opacity(isShowingStyleScreen ? 0 : 1)
                    .allowsHitTesting(!isShowingStyleScreen)
            }
            .opacity(isShowingMoreMenu ? 0 : 1)
            .blur(radius: isShowingMoreMenu ? 6 : 0)

            cameraLookControls

            // 타이머 카운트다운: 미리보기 가운데
            TimerCountdownView(countdown: camera.countdown)
                .position(x: layout.previewRect.midX, y: layout.previewRect.midY)

            // 더보기 메뉴: 판 바깥을 탭하면 닫힘
            if isShowingMoreMenu {
                Color.clear
                    .contentShape(.rect)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .onTapGesture { isShowingMoreMenu = false }
                VStack {
                    Spacer()
                    MoreMenu(camera: camera, isPresented: $isShowingMoreMenu) {
                        isShowingMoreMenu = false
                        isShowingStyleScreen = true
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8.5)
                .frame(width: layout.size.width, height: layout.size.height)
                // 셔터 자리에서 부풀어 나옴
                .transition(.glassPop(GlassPopTransition(anchor: UnitPoint(x: 0.5, y: layout.shutterCenterY / layout.size.height))))
            }

            // 빠른 설정 판: 상단 바 위로 내려옴. 판 바깥을 탭하면 닫힘
            if let kind = quickSettings {
                Color.clear
                    .contentShape(.rect)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .onTapGesture { quickSettings = nil }
                QuickSettingsView(camera: camera, kind: kind)
                    .frame(width: layout.size.width - 17)
                    // 판 위쪽이 상단 바 버튼 위쪽과 같은 높이
                    .offset(x: 8.5, y: layout.topBarCenterY - topBarControlHeight / 2)
                    // 누른 버튼 자리에서 부풀어 나옴
                    .transition(.glassPop(GlassPopTransition(anchor: kind == .flashAndLive ? .topTrailing : .topLeading,
                                                             scaleX: 0.3, scaleY: 0.45)))
            }

            // 전면 화면 플래시
            Color.white
                .frame(width: layout.size.width, height: layout.size.height)
                .opacity(camera.isScreenFlashing ? 1 : 0)
                .allowsHitTesting(false)

            StatusOverlayView(status: camera.status)
                .frame(width: layout.size.width, height: layout.size.height)
        }
        .animation(.easeOut(duration: 0.2), value: layers.openPanel)
        .animation(.easeOut(duration: 0.18), value: isShowingMoreMenu)
        .animation(.easeOut(duration: 0.18), value: quickSettings)
        .animation(.easeOut(duration: 0.2), value: isShowingCameraList)
        .animation(.easeInOut(duration: AppDefaults.macroButtonFadeDuration), value: camera.zoom.showsMacroButton)
        .animation(.spring(duration: 0.35, bounce: 0.1), value: isShowingStyleScreen)
        // 스타일을 바꾸면 사진 보정에 바로 반영
        .onChange(of: styles.selection) { _, selection in
            camera.photoStyle = selection
        }
        // 모드를 바꾸거나 녹화를 시작하면 메뉴를 닫음
        .onChange(of: camera.captureMode) {
            isShowingMoreMenu = false
            isShowingCameraList = false
            isShowingStyleScreen = false
            quickSettings = nil
        }
        .onChange(of: camera.captureActivity.isRecording) {
            isShowingMoreMenu = false
            isShowingCameraList = false
            quickSettings = nil
        }
        .onChange(of: camera.isLivePhotoActive) { _, isActive in
            guard camera.captureMode == .photo else { return }
            showLiveNotice(isActive)
        }
    }

    /// 셔터 왼쪽 카메라 버튼과 세로 목록. 색감이 사진에만 적용되므로 사진 모드에서만 보임
    @ViewBuilder
    private var cameraLookControls: some View {
        let isAvailable = camera.captureMode == .photo && camera.status == .running
            && !isShowingMoreMenu && !isShowingStyleScreen && !camera.prefersMinimizedUI
        let buttonTop = layout.shutterCenterY - CameraLookList.cellSize / 2
        if isShowingCameraList {
            // 목록 바깥을 탭하면 닫힘
            if AppDefaults.closesCameraListOnOutsideTap {
                Color.clear
                    .contentShape(.rect)
                    .frame(width: layout.size.width, height: layout.size.height)
                    .onTapGesture { isShowingCameraList = false }
            }
            let list = CameraLookList(looks: looks,
                                      maxHeight: buttonTop - CameraUI.cameraListGap - previewTopY,
                                      highlightedID: highlightedLookID) { item in
                selectLook(item)
                isShowingCameraList = false
            }
            let listBottom = buttonTop - CameraUI.cameraListGap
            list
                .position(x: CameraLayout.cameraButtonCenterX, y: listBottom - list.height / 2)
                // 버튼 위에서 위쪽으로 펼쳐짐
                .transition(.scale(scale: 0.4, anchor: UnitPoint(x: CameraLayout.cameraButtonCenterX / layout.size.width,
                                                                 y: listBottom / layout.size.height))
                    .combined(with: .opacity))
        }
        CameraLookButton(looks: looks, isListOpen: $isShowingCameraList, highlightedID: $highlightedLookID,
                         onSelect: selectLook)
            .position(x: CameraLayout.cameraButtonCenterX, y: layout.shutterCenterY)
            .opacity(isAvailable ? 1 : 0)
            .allowsHitTesting(isAvailable)
            .animation(.easeOut(duration: 0.2), value: isAvailable)
    }

    private static var cameraListGap: CGFloat { 8 }

    private func selectLook(_ item: CameraLookItem) {
        looks.select(item)
        camera.cameraLook = item.look
    }

    private var isShowingStyleIcon: Bool {
        camera.status == .running && camera.captureMode == .photo
            && !camera.captureActivity.isRecording && !camera.prefersMinimizedUI
    }

    private var isTopBarHidden: Bool {
        quickSettings != nil || isShowingMoreMenu || isShowingStyleScreen
    }

    /// 스타일 화면에서는 카드 위 분류 캡슐과 겹치므로 숨김
    private var isShowingLiveBadge: Bool {
        camera.captureMode == .photo && !isShowingStyleScreen
            && (camera.captureActivity.isLivePhoto || liveNotice != nil)
    }

    /// LIVE 켬 · 끔을 1.5초 동안 보여줌
    private func showLiveNotice(_ isOn: Bool) {
        liveNoticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { liveNotice = isOn }
        liveNoticeTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { liveNotice = nil }
        }
    }

    /// 미리보기 위쪽 끝. 비디오 · 16:9 사진은 미리보기가 상단 바 뒤까지 올라가므로 상단 바 아래부터
    private var previewTopY: CGFloat {
        max(layout.previewRect.minY, layout.safeTop + CameraLayout.topBarHeight)
    }

    private var smudgeBannerCenterY: CGFloat {
        guard layers.openPanel != nil else { return previewTopY + 24 }
        return layout.safeTop + CameraLayout.topBarHeight + panelHeight + 24
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}
