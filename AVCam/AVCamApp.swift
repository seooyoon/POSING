/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A sample app that shows how to a use the AVFoundation capture APIs to perform media capture.
*/

import os
import SwiftUI

@main
/// The AVCam app's main entry point.
struct AVCamApp: App {

    // Simulator doesn't support the AVFoundation capture APIs. Use the preview camera when running in Simulator.
#if targetEnvironment(simulator)
    // 시뮬레이터에서는 샘플 이미지를 보여주는 가짜 카메라 (CLAUDE.md 4절 7번)
    @State private var camera = PreviewCameraModel()
#else
    @State private var camera = CameraModel()
#endif
    
    // An indication of the scene's operational state.
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            CameraView(camera: camera)
                .statusBarHidden(true)
                .task {
                    // Start the capture pipeline.
                    await camera.start()
                }
                // Monitor the scene phase. Synchronize the persistent state when
                // the camera is running and the app becomes active.
                .onChange(of: scenePhase) { _, newPhase in
                    guard camera.status == .running, newPhase == .active else { return }
                    Task { @MainActor in
                        await camera.syncState()
                    }
                }
        }
    }
}

/// A global logger for the app.
let logger = Logger()
