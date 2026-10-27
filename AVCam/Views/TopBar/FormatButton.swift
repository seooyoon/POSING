//
//  FormatButton.swift
//  포징
//
//  상단 왼쪽 형식 버튼. 사진 `JPEG 24`, 비디오 `HD 해상도 30 FPS`.
//  지금은 표시만 하고, 사진 형식 전환은 4단계 · 비디오 설정은 5단계에서 연결한다.
//

import SwiftUI

struct FormatButton: View {

    let captureMode: CaptureMode

    var body: some View {
        Button {
            // 4단계(사진 형식) · 5단계(비디오 해상도 · FPS)에서 연결
        } label: {
            label
                .topBarCapsule()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var label: some View {
        switch captureMode {
        case .photo:
            // JPEG 옆에 작은 아래첨자 해상도
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("JPEG")
                small("24", baseline: -4)
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
        FormatButton(captureMode: .photo)
        FormatButton(captureMode: .video)
    }
    .padding()
    .background(.gray)
}
