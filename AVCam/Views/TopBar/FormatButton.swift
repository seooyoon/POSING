//
//  FormatButton.swift
//  포징
//
//  상단 왼쪽 형식 버튼. 사진 `JPEG 24`, 비디오 `HD 해상도 30 FPS`.
//  사진: 글자(HEIF/JPEG)를 누르면 형식, 숫자를 누르면 해상도 12 → 24 → 48 (지원하는 값만). 비디오 설정은 5단계.
//

import SwiftUI

struct FormatButton<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        label
            .topBarCapsule()
            .sensoryFeedback(.selection, trigger: camera.photoCodec)
            .sensoryFeedback(.selection, trigger: camera.photoResolution)
    }

    @ViewBuilder
    private var label: some View {
        switch camera.captureMode {
        case .photo:
            // 형식 옆에 작은 아래첨자 해상도. 둘을 따로 누름
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(camera.photoCodec.label)
                    .contentShape(.rect)
                    .onTapGesture { camera.photoCodec = camera.photoCodec.next }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("사진 형식 \(camera.photoCodec.label)")
                small("\(camera.activeResolution)", baseline: -4)
                    // 숫자가 작아서 누르는 범위를 조금 넓힘 (폭은 그대로)
                    .contentShape(Rectangle().inset(by: -8))
                    .onTapGesture { camera.photoResolution = camera.nextResolution() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("해상도 \(camera.activeResolution)메가픽셀")
            }
        case .video:
            // HD 해상도 · 30 FPS (작은 위첨자)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("HD")
                    small("해상도", baseline: 6)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("30")
                    small("FPS", baseline: 6)
                }
            }
        }
    }

    private func small(_ text: String, baseline: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10))
            .baselineOffset(baseline)
    }
}

#Preview {
    VStack {
        FormatButton(camera: PreviewCameraModel(captureMode: .photo))
        FormatButton(camera: PreviewCameraModel(captureMode: .video))
    }
    .padding()
    .background(.gray)
}
