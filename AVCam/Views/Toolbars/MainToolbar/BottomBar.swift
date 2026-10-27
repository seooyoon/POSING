//
//  BottomBar.swift
//  포징
//
//  하단 줄: 원형 썸네일 · `비디오 | 사진` · 전환 버튼 (docs/02_UI.md 7절)
//

import SwiftUI

struct BottomBar<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        HStack {
            ThumbnailButton(camera: camera)
            Spacer()
            CaptureModePicker(camera: camera)
            Spacer()
            SwitchCameraButton(camera: camera)
        }
        // 썸네일 · 전환 버튼 가운데가 화면 끝에서 약 58pt (기본 카메라 기준)
        .padding(.horizontal, 34)
        // 카메라 컨트롤 버튼을 밀고 있는 동안은 숨김
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
        .hidden(until: camera.status == .running)
    }
}

#Preview {
    BottomBar(camera: PreviewCameraModel(status: .running))
        .background(.black)
}
