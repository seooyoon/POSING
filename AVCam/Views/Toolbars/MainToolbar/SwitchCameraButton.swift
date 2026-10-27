/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays a button to switch between available cameras.
*/

import SwiftUI

/// 전면 · 후면 카메라 전환 버튼 (하단 오른쪽 원형)
struct SwitchCameraButton<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        Button {
            Task {
                await camera.switchVideoDevices()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: bottomRowButtonSize, height: bottomRowButtonSize)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(camera.captureActivity.isRecording)
        .allowsHitTesting(!camera.isSwitchingVideoDevices)
        // 녹화 중에는 기본 카메라처럼 숨김
        .opacity(camera.captureActivity.isRecording ? 0 : 1)
    }
}
