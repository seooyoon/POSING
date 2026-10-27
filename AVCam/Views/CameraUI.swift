/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents the main camera user interface.
*/

import SwiftUI

/// 카메라 화면 UI. 기본 카메라와 같은 자리에 상단 바 · 셔터 · 하단 줄을 놓는다.
struct CameraUI<CameraModel: Camera>: View {

    @State var camera: CameraModel
    let layout: CameraLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            TopBar(camera: camera)
                .frame(width: layout.size.width)
                .position(x: layout.centerX, y: layout.topBarCenterY)

            // 사진을 찍는 순간 미리보기 위쪽 가운데에 LIVE 표시
            LiveBadge()
                .opacity(camera.captureMode == .photo && camera.captureActivity.isLivePhoto ? 1 : 0)
                .position(x: layout.centerX, y: layout.previewRect.minY + 24)

            CaptureButton(camera: camera)
                .position(x: layout.centerX, y: layout.shutterCenterY)

            BottomBar(camera: camera)
                .frame(width: layout.size.width)
                .position(x: layout.centerX, y: layout.bottomRowCenterY)

            StatusOverlayView(status: camera.status)
                .frame(width: layout.size.width, height: layout.size.height)
        }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}
