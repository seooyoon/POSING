/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that retrieves camera and microphone devices.
*/

import AVFoundation
import Combine

/// An object that retrieves camera and microphone devices.
final class DeviceLookup {
    
    // Discovery sessions to find the front and back cameras, and external cameras in iPadOS.
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let externalCameraDiscoverSession: AVCaptureDevice.DiscoverySession
    
    init() {
        // 후면은 트리플 카메라 우선: 배율에 따라 초광각 · 메인 · 망원을 iOS가 자동 전환 (docs/05_TECH_NOTES.md 1절)
        backCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
                                                                      mediaType: .video,
                                                                      position: .back)
        frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
                                                                       mediaType: .video,
                                                                       position: .front)
        externalCameraDiscoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
                                                                         mediaType: .video,
                                                                         position: .unspecified)
        
        // 앱을 켤 때는 항상 후면 트리플 카메라로 시작 (기본 카메라와 같음). 지난번 전면을 기억하지 않음
        if let backCamera = backCameraDiscoverySession.devices.first {
            AVCaptureDevice.userPreferredCamera = backCamera
        }
    }
    
    /// 시작 카메라: 후면 우선, 없으면 시스템 기본
    var defaultCamera: AVCaptureDevice {
        get throws {
            guard let videoDevice = backCameraDiscoverySession.devices.first ?? AVCaptureDevice.systemPreferredCamera else {
                throw CameraError.videoDeviceUnavailable
            }
            return videoDevice
        }
    }
    
    /// Returns the default microphone for the device on which the app runs.
    var defaultMic: AVCaptureDevice {
        get throws {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                throw CameraError.audioDeviceUnavailable
            }
            return audioDevice
        }
    }
    
    var cameras: [AVCaptureDevice] {
        // Populate the cameras array with the available cameras.
        var cameras: [AVCaptureDevice] = []
        if let backCamera = backCameraDiscoverySession.devices.first {
            cameras.append(backCamera)
        }
        if let frontCamera = frontCameraDiscoverySession.devices.first {
            cameras.append(frontCamera)
        }
        // iPadOS supports connecting external cameras.
        if let externalCamera = externalCameraDiscoverSession.devices.first {
            cameras.append(externalCamera)
        }
        
#if !targetEnvironment(simulator)
        if cameras.isEmpty {
            fatalError("No camera devices are found on this system.")
        }
#endif
        return cameras
    }
}
