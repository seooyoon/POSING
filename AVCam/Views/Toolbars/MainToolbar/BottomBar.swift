//
//  BottomBar.swift
//  포징
//
//  하단 줄: 원형 썸네일 · `비디오 | 사진` · 전환 버튼 (docs/02_UI.md 7절)
//

import SwiftUI

struct BottomBar<CameraModel: Camera>: View {

    @State var camera: CameraModel
    /// 모드 캡슐을 꾹 눌러 모드 줄이 펼쳐짐
    @State private var isModeStripExpanded = false

    var body: some View {
        HStack {
            // 모드 줄이 펼쳐지면 기본 카메라처럼 썸네일 · 전환 버튼이 사라짐
            ThumbnailButton(camera: camera)
                .opacity(isModeStripExpanded ? 0 : 1)
            Spacer()
            CaptureModePicker(camera: camera, isExpanded: $isModeStripExpanded)
            Spacer()
            SwitchCameraButton(camera: camera)
                .opacity(isModeStripExpanded ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.2), value: isModeStripExpanded)
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
