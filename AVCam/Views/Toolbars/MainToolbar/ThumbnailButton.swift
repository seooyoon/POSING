/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays a thumbnail of the last captured media.
*/

import SwiftUI

/// 방금 찍은 사진 · 영상의 원형 썸네일.
///
/// 누르면 앱 자체 갤러리가 아니라 아이폰 기본 사진 앱을 연다 (CLAUDE.md 4절 5번).
struct ThumbnailButton<CameraModel: Camera>: View {

    @State var camera: CameraModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            // 애플 공식 문서에 없는 주소라 열리지 않으면 아무 동작 안 함 (05_TECH_NOTES 7절)
            if let url = URL(string: "photos-redirect://") {
                openURL(url)
            }
        } label: {
            thumbnail
                .frame(width: bottomRowButtonSize, height: bottomRowButtonSize)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(camera.captureActivity.isRecording)
        // 녹화 중에는 기본 카메라처럼 숨김
        .opacity(camera.captureActivity.isRecording ? 0 : 1)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnail = camera.thumbnail {
            Image(thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .animation(.easeInOut(duration: 0.3), value: thumbnail)
        } else {
            // 아직 찍은 게 없으면 기본 카메라처럼 빈 어두운 원
            Circle()
                .fill(Color(white: 0.1))
        }
    }
}
