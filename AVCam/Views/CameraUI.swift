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
    let layout: CameraLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            TopBar(camera: camera, layers: layers)
                .frame(width: layout.size.width)
                .position(x: layout.centerX, y: layout.topBarCenterY)

            // 포즈 · MY 패널: 상단 바 바로 아래, 한 번에 하나만. 전환할 때는 내용만 바뀜
            if let kind = layers.openPanel {
                LayerPanel(layers: layers, kind: kind)
                    .frame(width: layout.size.width)
                    .offset(y: layout.safeTop + CameraLayout.topBarHeight)
                    .transition(.offset(y: -12).combined(with: .opacity))
            }

            // 사진을 찍는 순간 미리보기 위쪽 가운데에 LIVE 표시
            LiveBadge()
                .opacity(camera.captureMode == .photo && camera.captureActivity.isLivePhoto ? 1 : 0)
                .position(x: layout.centerX, y: layout.previewRect.minY + 24)

            // 렌즈가 더러우면 미리보기 위쪽 가운데에 안내 (기본 카메라와 같은 자리)
            LensSmudgeBanner(isSmudged: camera.isLensSmudged)
                .position(x: layout.centerX, y: layout.previewRect.minY + 24)

            // 배율 버튼 · 다이얼 (버튼 줄이 아래쪽, 다이얼은 위로 펼쳐짐)
            if camera.zoom.isAvailable {
                ZoomControl(camera: camera)
                    .frame(width: layout.size.width)
                    .position(x: layout.centerX, y: layout.zoomRowCenterY + 20 - ZoomControl<CameraModel>.height / 2)
            }
            // 전면 카메라는 배율 버튼 자리에 화각 버튼
            if camera.zoom.isFrontCamera {
                FrontFieldOfViewButton(camera: camera)
                    .position(x: layout.centerX, y: layout.zoomRowCenterY)
            }
            // 접사 중이거나 접사 전환을 꺼 두면 왼쪽 아래 꽃 버튼
            if camera.zoom.showsMacroButton {
                MacroButton(camera: camera)
                    .position(x: CameraLayout.sideInset + 22, y: layout.zoomRowCenterY)
            }

            CaptureButton(camera: camera)
                .position(x: layout.centerX, y: layout.shutterCenterY)

            BottomBar(camera: camera)
                .frame(width: layout.size.width)
                .position(x: layout.centerX, y: layout.bottomRowCenterY)

            StatusOverlayView(status: camera.status)
                .frame(width: layout.size.width, height: layout.size.height)
        }
        .animation(.easeOut(duration: 0.2), value: layers.openPanel)
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}
