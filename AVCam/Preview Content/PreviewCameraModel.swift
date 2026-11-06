/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A Camera implementation to use when working with SwiftUI previews.
*/

import Foundation
import SwiftUI

@Observable
class PreviewCameraModel: Camera {
    
    var isLivePhotoEnabled = true
    var prefersMinimizedUI = false
    var qualityPrioritization = QualityPrioritization.quality
    var shouldFlashScreen = false
    var isHDRVideoSupported = false
    var isLensSmudged = false
    // 시뮬레이터에는 렌즈가 없어서 배율 버튼만 반응
    private(set) var zoom = ZoomState(displayFactor: 1, range: 0.5...25, presets: ZoomState.presetValues)
    var isHDRVideoEnabled = false
    var flashMode = FlashMode.auto
    var timerDuration = TimerDuration.off
    var exposureCompensation: Float = 0
    var photoAspect = PhotoAspect.fourThree
    var photoCodec = PhotoCodec.jpeg
    var photoResolution = 24
    var videoMode = VideoMode(resolution: AppDefaults.videoResolution, frameRate: AppDefaults.videoFrameRate)
    let availableVideoModes = Set<VideoMode>()
    var slowMotionFrameRate = AppDefaults.slowMotionFrameRate
    // 시뮬레이터: 아이폰 16 Pro 후면처럼
    var availableResolutions: [Int] { PhotoResolution.selectable(from: PhotoResolution.values, codec: activeCodec) }
    let isRAWSupported = true
    var isSceneDark = false
    private let captureTimer = CaptureTimer()
    var countdown: Int? { captureTimer.countdown }
    private(set) var isScreenFlashing = false
    
    struct PreviewSourceStub: PreviewSource {
        // Stubbed out for test purposes.
        func connect(to target: PreviewTarget) {}
    }
    
    let previewSource: PreviewSource = PreviewSourceStub()
    
    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    var captureMode = CaptureMode.photo {
        didSet {
            isSwitchingModes = true
            Task {
                // Create a short delay to mimic the time it takes to reconfigure the session.
                try? await Task.sleep(until: .now + .seconds(0.3), clock: .continuous)
                self.isSwitchingModes = false
            }
        }
    }
    private(set) var isSwitchingModes = false
    private(set) var isVideoDeviceSwitchable = true
    private(set) var isSwitchingVideoDevices = false
    private(set) var thumbnail: CGImage?
    
    var error: Error?
    
    init(captureMode: CaptureMode = .photo, status: CameraStatus = .unknown) {
        self.captureMode = captureMode
        self.status = status
    }
    
    func start() async {
        if status == .unknown {
            status = .running
        }
    }
    
    // 시뮬레이터에서도 전면 화각 버튼을 확인: 후면 ↔ 전면 상태만 바꿈 (전면은 '가깝게'로 시작)
    func switchVideoDevices() {
        zoom = zoom.isFrontCamera
            ? ZoomState(displayFactor: 1, range: 0.5...25, presets: ZoomState.presetValues)
            : ZoomState(isFrontCamera: true, isFrontWide: false)
    }
    
    // 시뮬레이터 셔터 흉내: 화면을 깜빡이고 샘플 이미지를 썸네일로 보여줌 (05_TECH_NOTES 13절)
    func capturePhoto() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
        thumbnail = UIImage(named: "photo_mode")?.cgImage
    }

    // 시뮬레이터에서도 타이머 화면을 확인
    func shutterPressed() async {
        await captureTimer.shutterPressed(duration: timerDuration) { [weak self] in
            self?.capturePhoto()
        }
    }

    // 시뮬레이터 녹화 흉내: 녹화 중 화면(빨간 시간 · 숨는 버튼)을 확인하는 용도
    func toggleRecording() {
        if captureActivity.isRecording {
            captureActivity = .idle
            thumbnail = UIImage(named: "video_mode")?.cgImage
        } else {
            captureActivity = .movieCapture()
        }
    }
    
    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }

    // 시뮬레이터에는 카메라가 없어서 화면 표시만 반응
    func lockFocusAndExposure(at point: CGPoint) {}

    func setExposureBias(_ bias: Float) {}

    func setZoom(_ displayFactor: CGFloat, animated: Bool) {
        zoom.displayFactor = min(max(displayFactor, zoom.range.lowerBound), zoom.range.upperBound)
    }

    func setAutoMacroEnabled(_ isEnabled: Bool) {
        zoom.isAutoMacroEnabled = isEnabled
    }

    func setFrontWide(_ isWide: Bool) {
        zoom.isFrontWide = isWide
    }
    
    private func capabilities(for mode: CaptureMode) -> CaptureCapabilities {
        switch mode {
        case .photo:
            return CaptureCapabilities(isLivePhotoCaptureSupported: true)
        case .video, .slowMotion, .timelapse:
            return CaptureCapabilities(isLivePhotoCaptureSupported: false,
                                       isHDRSupported: true)
        }
    }
    
    func syncState() async {
        logger.debug("Syncing state isn't implemented in PreviewCamera.")
    }
}
