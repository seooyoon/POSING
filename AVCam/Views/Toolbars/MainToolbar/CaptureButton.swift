/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays an appropriate capture button for the selected capture mode.
*/

import SwiftUI

/// A view that displays an appropriate capture button for the selected mode.
@MainActor
struct CaptureButton<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    @State var isRecording = false
    
    // 기본 카메라 셔터 바깥 지름 (iPhone 16 Pro 기준 약 80pt)
    private let mainButtonDimension: CGFloat = 80
    
    var body: some View {
        captureButton
            .aspectRatio(1.0, contentMode: .fit)
            .frame(width: mainButtonDimension)
            // Respond to recording state changes that occur from hardware button presses.
            .onChange(of: camera.captureActivity.isRecording) { _, newValue in
                // Ensure the button animation occurs when toggling recording state from a hardware button.
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecording = newValue
                }
            }
    }
    
    @ViewBuilder
    var captureButton: some View {
        switch camera.captureMode {
        case .photo:
            PhotoCaptureButton(isSceneDark: camera.isSceneDark) {
                Task {
                    // 타이머가 켜져 있으면 카운트다운
                    await camera.shutterPressed()
                }
            }
        case .video:
            MovieCaptureButton(isRecording: $isRecording, isSceneDark: camera.isSceneDark) { _ in
                Task {
                    await camera.toggleRecording()
                }
            }
        }
    }
}

#Preview("Photo") {
    CaptureButton(camera: PreviewCameraModel(captureMode: .photo))
}

#Preview("Video") {
    CaptureButton(camera: PreviewCameraModel(captureMode: .video))
}

/// 셔터 바깥 링: 반투명 회색 + 얇고 밝은 테두리. 어두운 장면에서는 링이 어두워지고 테두리만 보임
private struct ShutterRing: View {
    static let width: CGFloat = 6
    let isSceneDark: Bool

    var body: some View {
        Circle()
            .strokeBorder(Color(white: 0.5).opacity(isSceneDark ? 0.35 : 0.7), lineWidth: Self.width)
            .overlay(Circle().strokeBorder(.white.opacity(isSceneDark ? 0.3 : 0.18), lineWidth: 0.5))
            .animation(.easeInOut(duration: 0.3), value: isSceneDark)
    }
}

private struct PhotoCaptureButton: View {
    private let isSceneDark: Bool
    private let action: () -> Void
    
    init(isSceneDark: Bool, action: @escaping () -> Void) {
        self.isSceneDark = isSceneDark
        self.action = action
    }
    
    var body: some View {
        ZStack {
            ShutterRing(isSceneDark: isSceneDark)
            Button {
                action()
            } label: {
                Circle()
                    .inset(by: ShutterRing.width)
                    .fill(.white)
            }
            .buttonStyle(PhotoButtonStyle())
        }
    }
    
    struct PhotoButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

private struct MovieCaptureButton: View {
    
    private let isSceneDark: Bool
    private let action: (Bool) -> Void
    
    @Binding private var isRecording: Bool
    
    init(isRecording: Binding<Bool>, isSceneDark: Bool, action: @escaping (Bool) -> Void) {
        self.isSceneDark = isSceneDark
        _isRecording = isRecording
        self.action = action
    }
    
    var body: some View {
        ZStack {
            ShutterRing(isSceneDark: isSceneDark)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecording.toggle()
                }
                action(isRecording)
            } label: {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: geometry.size.width / (isRecording ? 4.0 : 2.0))
                        .inset(by: ShutterRing.width)
                        .fill(.red)
                        .scaleEffect(isRecording ? 0.6 : 1.0)
                }
            }
            .buttonStyle(NoFadeButtonStyle())
        }
    }
    
    struct NoFadeButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}
