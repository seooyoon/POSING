//
//  TopBar.swift
//  포징
//
//  상단 바: 형식 버튼 · 초기화 · 포즈 · MY · [플래시 · LIVE · •••] (docs/02_UI.md 2절)
//

import SwiftUI

struct TopBar<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        HStack(spacing: 8) {
            if camera.captureActivity.isRecording {
                // 녹화 중에는 기본 카메라처럼 녹화 시간만 보임
                Spacer()
                RecordingTimeView(time: camera.captureActivity.currentTime)
                Spacer()
            } else {
                FormatButton(captureMode: camera.captureMode)
                // 초기화 · 포즈 · MY: 따로 떨어진 버튼 3개. 동작은 2단계에서 연결
                PosingButton(title: "초기화") {}
                PosingButton(title: "포즈") {}
                PosingButton(title: "MY") {}
                Spacer(minLength: 0)
                TopControlsCapsule(camera: camera)
            }
        }
        .padding(.horizontal, CameraLayout.sideInset)
        // 카메라 컨트롤 버튼을 밀고 있는 동안은 숨김
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
        .hidden(until: camera.status == .running)
    }
}

/// 초기화 · 포즈 · MY 버튼. 형식 버튼과 같은 높이 · 배경 · 글자 크기, 폭은 글자에 맞춤
struct PosingButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .topBarCapsule(horizontalPadding: 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TopBar(camera: PreviewCameraModel(status: .running))
        .background(.gray)
}
