/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

@MainActor
struct CameraView<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        GeometryReader { proxy in
            let layout = CameraLayout(proxy: proxy, captureMode: camera.captureMode)
            ZStack(alignment: .topLeading) {
                // 카메라 화면은 다크 고정 (docs/02_UI.md 10절)
                Color.black
                // 미리보기는 모드에 맞는 자리 · 비율로 (사진 4:3, 비디오 16:9)
                PreviewContainer(camera: camera) {
                    preview
                }
                .frame(width: layout.previewRect.width, height: layout.previewRect.height)
                .clipped()
                .position(x: layout.previewRect.midX, y: layout.previewRect.midY)
                .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
                // 카메라 화면 UI
                CameraUI(camera: camera, layout: layout)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    /// A view that provides a preview of the captured content.
    private var preview: some View {
        CameraPreview(source: camera.previewSource)
            // Handle capture events from device hardware buttons.
            .onCameraCaptureEvent(defaultSoundDisabled: true) { event in
                if event.phase == .ended {
                    let sound: AVCaptureEventSound
                    switch camera.captureMode {
                    case .photo:
                        sound = .cameraShutter
                        // Capture a photo when pressing a hardware button.
                        await camera.capturePhoto()
                    case .video:
                        sound = camera.captureActivity.isRecording ?
                            .endVideoRecording : .beginVideoRecording
                        // Toggle video recording when pressing a hardware button.
                        await camera.toggleRecording()
                    }
                    // Play a sound when capturing by clicking an AirPods stem.
                    if event.shouldPlaySound {
                        event.play(sound)
                    }
                }
            }
            // Focus and expose at the tapped point.
            .onTapGesture { location in
                Task { await camera.focusAndExpose(at: location) }
            }
            // 미리보기를 좌우로 밀어 모드 전환 (기본 카메라와 같은 방향)
            .simultaneousGesture(swipeGesture)
            /// The value of `shouldFlashScreen` changes briefly to `true` when capture
            /// starts, and then immediately changes to `false`. Use this change to
            /// flash the screen to provide visual feedback when capturing photos.
            .opacity(camera.shouldFlashScreen ? 0 : 1)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                guard !camera.captureActivity.isRecording else { return }
                let direction: SwipeDirection = value.translation.width < 0 ? .left : .right
                camera.captureMode = CaptureModePicker<CameraModel>.mode(after: camera.captureMode, swipe: direction)
            }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel(status: .running))
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
