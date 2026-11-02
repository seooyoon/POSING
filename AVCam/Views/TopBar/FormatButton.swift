//
//  FormatButton.swift
//  포징
//
//  상단 왼쪽 형식 버튼. 사진 `JPEG 24`, 비디오 `HD 해상도 30 FPS`.
//  사진: 탭하거나 꾹 누르면 포맷(HEIF · JPEG) · 해상도(12 · 24 · 48MP) 빠른 설정 판. 비디오 설정은 5단계.
//

import SwiftUI

struct FormatButton<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var quickSettings: QuickSettingsKind?

    var body: some View {
        label
            .topBarCapsule()
            .contentShape(.capsule)
            // 기본 카메라처럼 탭 · 꾹 누르기 모두 빠른 설정 판
            .onTapGesture { openFormatSettings() }
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) { openFormatSettings() }
            .accessibilityAddTraits(camera.captureMode == .photo ? .isButton : [])
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
                small("\(camera.activeResolution)", baseline: -4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("사진 형식 \(camera.photoCodec.label), 해상도 \(camera.activeResolution)메가픽셀")
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

    private func openFormatSettings() {
        guard camera.captureMode == .photo else { return }
        quickSettings = .format
    }

    private func small(_ text: String, baseline: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10))
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
