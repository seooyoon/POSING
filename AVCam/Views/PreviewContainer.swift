/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that provides a container view around the camera preview.
*/

import SwiftUI

// Portrait-orientation aspect ratios.
typealias AspectRatio = CGSize
let photoAspectRatio = AspectRatio(width: 3.0, height: 4.0)
let movieAspectRatio = AspectRatio(width: 9.0, height: 16.0)

/// A view that provides a container view around the camera preview.
///
/// This view applies transition effects when changing capture modes or switching devices.
/// 미리보기의 자리 · 크기는 `CameraView`가 `CameraLayout`으로 정한다.
@MainActor
struct PreviewContainer<Content: View, CameraModel: Camera>: View {

    @State var camera: CameraModel

    @Environment(\.scenePhase) private var scenePhase

    // State values for transition effects.
    @State private var blurRadius = CGFloat.zero
    @State private var coverOpacity = 0.0

    private let content: Content

    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }

    var body: some View {
        previewView
    }
    
    /// Attach animations to the camera preview.
    var previewView: some View {
        content
            .blur(radius: blurRadius, opaque: true)
            .overlay(Color.black.opacity(coverOpacity))
            .onChange(of: camera.isSwitchingModes, updateBlurRadius(_:_:))
            .onChange(of: camera.isSwitchingVideoDevices, updateBlurRadius(_:_:))
            .onChange(of: scenePhase, updateCoverOpacity(_:_:))
    }
    
    func updateBlurRadius(_: Bool, _ isSwitching: Bool) {
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }

    /// Covers the preview as the app enters the background, and reveals it on return.
    ///
    /// A preview that isn't covered on the way out reappears holding the frame it last
    /// rendered. Covering it first means a person doesn't see that stale frame, and the
    /// reveal fades the cover away as live frames resume.
    func updateCoverOpacity(_: ScenePhase, _ phase: ScenePhase) {
        switch phase {
        case .background:
            coverOpacity = 1
        case .active:
            withAnimation(.easeIn(duration: 0.3)) {
                coverOpacity = 0
            }
        default:
            break
        }
    }
}
