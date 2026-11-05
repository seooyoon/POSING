//
//  FormatButton.swift
//  포징
//
//  상단 왼쪽 형식 버튼. 사진 `JPEG 24`, 비디오 `4K 해상도 30 FPS`.
//  탭하거나 꾹 누르면 빠른 설정 판: 사진은 포맷 · 해상도, 비디오는 해상도 · 프레임률.
//

import SwiftUI

struct FormatButton<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var quickSettings: QuickSettingsKind?

    var body: some View {
        label
            // 상단 바에 버튼이 더 있어 비디오 글자가 길면 여백을 줄임
            .topBarCapsule(horizontalPadding: camera.captureMode == .photo ? 12 : camera.captureMode == .slowMotion ? 8 : 10)
            .contentShape(.capsule)
            // 기본 카메라처럼 탭 · 꾹 누르기 모두 빠른 설정 판
            .onTapGesture { openFormatSettings() }
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) { openFormatSettings() }
            .accessibilityAddTraits(.isButton)
            .sensoryFeedback(.selection, trigger: camera.photoCodec)
            .sensoryFeedback(.selection, trigger: camera.photoResolution)
            .sensoryFeedback(.selection, trigger: camera.videoMode)
            .sensoryFeedback(.selection, trigger: camera.slowMotionFrameRate)
    }

    @ViewBuilder
    private var label: some View {
        switch camera.captureMode {
        case .photo:
            // 형식 옆에 작은 아래첨자 해상도. 둘을 따로 누름
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(camera.activeCodec.label)
                small("\(camera.activeResolution)", baseline: -4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("사진 형식 \(camera.activeCodec.label), 해상도 \(camera.activeResolution)메가픽셀")
        case .video, .slowMotion, .timelapse:
            // 4K 해상도 · 30 FPS (작은 위첨자)
            HStack(alignment: .firstTextBaseline, spacing: camera.captureMode == .slowMotion ? 6 : 8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(camera.captureMode == .slowMotion ? VideoResolution.hd.label : camera.videoMode.resolution.label)
                    small("해상도", baseline: 6)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(camera.captureMode == .slowMotion ? camera.slowMotionFrameRate : camera.videoMode.frameRate)").font(.cameraDigits(size: topBarFontSize))
                    small("FPS", baseline: 6)
                }
            }
        }
    }

    private func openFormatSettings() {
        quickSettings = camera.captureMode == .photo ? .format : .videoFormat
    }

    private func small(_ text: String, baseline: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.6))
            .baselineOffset(baseline)
    }
}

#Preview {
    VStack {
        FormatButton(camera: PreviewCameraModel(captureMode: .photo), quickSettings: .constant(nil))
        FormatButton(camera: PreviewCameraModel(captureMode: .video), quickSettings: .constant(nil))
    }
    .padding()
    .background(.gray)
}
