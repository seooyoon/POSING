/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that provides the interface to the features of the camera.
*/

import SwiftUI
import Combine
import AVFoundation

/// An object that provides the interface to the features of the camera.
///
/// This object provides the default implementation of the `Camera` protocol, which defines the interface
/// to configure the camera hardware and capture media. `CameraModel` doesn't perform capture itself, but is an
/// `@Observable` type that mediates interactions between the app's SwiftUI views and `CaptureService`.
///
/// For SwiftUI previews and Simulator, the app uses `PreviewCameraModel` instead.
///
@MainActor
@Observable
final class CameraModel: Camera {
    
    /// The current status of the camera, such as unauthorized, running, or failed.
    private(set) var status = CameraStatus.unknown
    
    /// The current state of photo or movie capture.
    private(set) var captureActivity = CaptureActivity.idle
    
    /// A Boolean value that indicates whether the app is currently switching video devices.
    private(set) var isSwitchingVideoDevices = false
    
    /// A Boolean value that indicates whether the camera prefers showing a minimized set of UI controls.
    private(set) var prefersMinimizedUI = false
    
    /// A Boolean value that indicates whether the app is currently switching capture modes.
    private(set) var isSwitchingModes = false
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins.
    private(set) var shouldFlashScreen = false
    
    /// A thumbnail for the last captured photo or video.
    private(set) var thumbnail: CGImage?
    
    /// An error that indicates the details of an error during photo or movie capture.
    private(set) var error: Error?
    
    /// An object that provides the connection between the capture session and the video preview layer.
    var previewSource: PreviewSource { captureService.previewSource }
    
    /// A Boolean that indicates whether the camera supports HDR video recording.
    private(set) var isHDRVideoSupported = false

    private(set) var isLensSmudged = false

    private(set) var zoom = ZoomState.unavailable

    private(set) var countdown: Int?
    private var countdownTask: Task<Void, Never>?

    private(set) var isScreenFlashing = false
    /// 지금 카메라의 사진 출력이 플래시를 지원
    private var isFlashSupported = false
    /// 지금 카메라가 찍을 수 있는 사진 크기
    private var photoDimensions: [CMVideoDimensions] = []
    private(set) var availableResolutions: [Int] = []
    
    /// An object that saves captured media to a person's Photos library.
    private let mediaLibrary = MediaLibrary()
    
    /// An object that manages the app's capture functionality.
    private let captureService = CaptureService()
    
    /// Persistent state shared between the app and capture extension.
    private var cameraState = CameraState()
    
    init() {
        //
    }
    
    // MARK: - Starting the camera
    /// Start the camera and begin the stream of data.
    func start() async {
        // Verify that the person authorizes the app to use device cameras and microphones.
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        do {
            // Synchronize the state of the model with the persistent state.
            await syncState()
            // 저장된 비율이 16:9 · 1:1이면 세션을 시작하기 전에 지연 처리를 끔
            await captureService.setPhotoCropping(photoAspect != .fourThree)
            // Start the capture service to start the flow of data.
            try await captureService.start(with: cameraState)
            observeState()
            status = .running
            updateTorch()
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }
    
    /// Synchronizes the persistent camera state.
    ///
    /// `CameraState` represents the persistent state, such as the capture mode, that the app and extension share.
    func syncState() async {
        cameraState = await CameraState.current
        captureMode = cameraState.captureMode
        qualityPrioritization = cameraState.qualityPrioritization
        isLivePhotoEnabled = cameraState.isLivePhotoEnabled
        isHDRVideoEnabled = cameraState.isVideoHDREnabled
    }
    
    // MARK: - Changing modes and devices
    
    /// A value that indicates the mode of capture for the camera.
    var captureMode = CaptureMode.photo {
        didSet {
            // 같은 모드를 다시 넣으면(끝에서 더 밀기 등) 세션을 다시 구성하지 않음
            guard status == .running, captureMode != oldValue else { return }
            cancelCountdown()
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                // Update the configuration of the capture service for the new mode.
                try? await captureService.setCaptureMode(captureMode)
                // Update the persistent state value.
                cameraState.captureMode = captureMode
                updateTorch()
            }
        }
    }
    
    /// Selects the next available video device for capture.
    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false }
        await captureService.selectNextVideoDevice()
        // 전환 직후 셔터를 눌러도 새 카메라의 플래시 · 해상도 값을 쓰도록 바로 맞춤
        applyPhotoCapabilities(await captureService.captureCapabilities)
    }
    
    // MARK: - Photo capture
    
    /// Captures a photo and writes it to the user's Photos library.
    func capturePhoto() async {
        // 카메라를 바꾸는 중에는 찍지 않음 (이전 카메라 값으로 찍히지 않게)
        guard !isSwitchingVideoDevices else { return }
        // 비율을 막 바꿨으면 지연 처리 설정이 끝난 뒤에 찍음 (지연 처리 사진은 자를 수 없음)
        await photoAspectTask?.value
        // 전면 카메라가 플래시를 지원하지 않으면 촬영 순간 화면을 하얗게 밝혀 대신함
        let usesScreenFlash = zoom.isFrontCamera && !isFlashSupported && flashMode == .on
        if usesScreenFlash {
            await showScreenFlash()
        }
        do {
            let photoFeatures = PhotoFeatures(isLivePhotoEnabled: isLivePhotoActive,
                                              qualityPrioritization: qualityPrioritization,
                                              flashMode: AVCaptureDevice.FlashMode(flashMode),
                                              cropRatio: photoAspect.cropLongToShort,
                                              codec: photoCodec == .heif ? .hevc : .jpeg,
                                              maxDimensions: activeDimensions)
            let photo = try await captureService.capturePhoto(with: photoFeatures)
            if usesScreenFlash { hideScreenFlash() }
            try await mediaLibrary.save(photo: photo)
        } catch {
            if usesScreenFlash { hideScreenFlash() }
            self.error = error
        }
    }

    func shutterPressed() async {
        if countdownTask != nil {
            cancelCountdown()
            return
        }
        guard timerDuration != .off else {
            await capturePhoto()
            return
        }
        countdownTask = Task {
            for remaining in stride(from: timerDuration.rawValue, to: 0, by: -1) {
                countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            countdownTask = nil
            await capturePhoto()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    var flashMode = FlashMode.saved {
        didSet {
            flashMode.save()
            updateTorch()
        }
    }

    var timerDuration = TimerDuration.saved {
        didSet { timerDuration.save() }
    }

    var exposureCompensation: Float = 0 {
        didSet {
            Task { await captureService.setExposureCompensation(exposureCompensation) }
        }
    }

    var photoAspect = PhotoAspect.saved {
        didSet {
            photoAspect.save()
            applyPhotoAspect()
        }
    }

    var photoCodec = PhotoCodec.saved {
        didSet { photoCodec.save() }
    }

    var photoResolution = PhotoResolution.saved {
        didSet { PhotoResolution.save(photoResolution) }
    }

    /// 고른 해상도에 맞는 장치 사진 크기
    private var activeDimensions: CMVideoDimensions? {
        photoDimensions.last {
            PhotoResolution.megapixels(width: $0.width, height: $0.height) == activeResolution
        }
    }

    private var photoAspectTask: Task<Void, Never>?

    private func applyPhotoAspect() {
        let isCropping = photoAspect != .fourThree
        let previous = photoAspectTask
        photoAspectTask = Task {
            // 빠르게 여러 번 바꿔도 순서대로 적용
            await previous?.value
            await captureService.setPhotoCropping(isCropping)
        }
    }

    /// 비디오 모드에서만 플래시 값대로 조명을 켬
    private func updateTorch() {
        let mode = captureMode == .video ? flashMode : .off
        Task { await captureService.setTorchMode(mode) }
    }

    private func showScreenFlash() async {
        withAnimation(.easeIn(duration: 0.15)) { isScreenFlashing = true }
        // 화면이 밝아지고 노출이 맞춰질 시간
        try? await Task.sleep(for: .milliseconds(400))
    }

    private func hideScreenFlash() {
        withAnimation(.easeOut(duration: 0.3)) { isScreenFlashing = false }
    }
    
    /// A Boolean value that indicates whether to capture Live Photos when capturing stills.
    var isLivePhotoEnabled = true {
        didSet {
            // Update the persistent state value.
            cameraState.isLivePhotoEnabled = isLivePhotoEnabled
        }
    }
    
    /// A value that indicates how to balance the photo capture quality versus speed.
    var qualityPrioritization = QualityPrioritization.quality {
        didSet {
            // Update the persistent state value.
            cameraState.qualityPrioritization = qualityPrioritization
        }
    }
    
    /// Performs a focus and expose operation at the specified screen point.
    func focusAndExpose(at point: CGPoint) async {
        await captureService.focusAndExpose(at: point)
    }

    func setZoom(_ displayFactor: CGFloat, animated: Bool) async {
        await captureService.setZoom(displayFactor, animated: animated)
    }

    func setAutoMacroEnabled(_ isEnabled: Bool) async {
        await captureService.setAutoMacroEnabled(isEnabled)
    }

    func setFrontWide(_ isWide: Bool) async {
        await captureService.setFrontWide(isWide)
    }

    func lockFocusAndExposure(at point: CGPoint) async {
        await captureService.lockFocusAndExposure(at: point)
    }

    func setExposureBias(_ bias: Float) async {
        await captureService.setExposureBias(bias)
    }
    
    /// Sets the `showCaptureFeedback` state to indicate that capture is underway.
    private func flashScreen() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
    }
    
    // MARK: - Video capture
    /// A Boolean value that indicates whether the camera captures video in HDR format.
    var isHDRVideoEnabled = false {
        didSet {
            guard status == .running, captureMode == .video else { return }
            Task {
                await captureService.changeHDRVideo(isHDRVideoEnabled)
                // Update the persistent state value.
                cameraState.isVideoHDREnabled = isHDRVideoEnabled
            }
        }
    }
    
    /// Toggles the state of recording.
    func toggleRecording() async {
        switch await captureService.captureActivity {
        case .movieCapture:
            do {
                // If currently recording, stop the recording and write the movie to the library.
                let movie = try await captureService.stopRecording()
                try await mediaLibrary.save(movie: movie)
            } catch {
                self.error = error
            }
        default:
            // In any other case, start recording.
            await captureService.startRecording()
        }
    }
    
    /// 사진 모드일 때만 사진 출력 값(플래시 · 해상도)을 받음
    private func applyPhotoCapabilities(_ capabilities: CaptureCapabilities) {
        guard captureMode == .photo else { return }
        isFlashSupported = capabilities.isFlashSupported
        photoDimensions = capabilities.photoDimensions
        // 같은 MP 크기가 여러 개면 하나로
        availableResolutions = Array(Set(capabilities.photoDimensions.map {
            PhotoResolution.megapixels(width: $0.width, height: $0.height)
        })).sorted()
    }

    // MARK: - Internal state observations
    
    // Set up camera's state observations.
    private func observeState() {
        Task {
            // Await new thumbnails that the media library generates when saving a file.
            for await thumbnail in mediaLibrary.thumbnails.compactMap({ $0 }) {
                self.thumbnail = thumbnail
            }
        }
        
        Task {
            // Await new capture activity values from the capture service.
            for await activity in await captureService.$captureActivity.values {
                if activity.willCapture {
                    // Flash the screen to indicate capture is starting.
                    flashScreen()
                } else {
                    // Forward the activity to the UI.
                    captureActivity = activity
                }
            }
        }
        
        Task {
            // Await updates to the capabilities that the capture service advertises.
            for await capabilities in await captureService.$captureCapabilities.values {
                isHDRVideoSupported = capabilities.isHDRSupported
                applyPhotoCapabilities(capabilities)
                cameraState.isVideoHDRSupported = capabilities.isHDRSupported
            }
        }
        
        Task {
            // 배율 · 접사 상태 (카메라 컨트롤 버튼으로 바꿔도 따라옴)
            for await zoom in await captureService.$zoomState.values {
                self.zoom = zoom
            }
        }

        Task {
            // 렌즈 얼룩 감지 결과
            for await isLensSmudged in await captureService.$isLensSmudged.values {
                withAnimation {
                    self.isLensSmudged = isLensSmudged
                }
            }
        }

        Task {
            // Await updates to a person's interaction with the Camera Control HUD.
            for await isShowingFullscreenControls in await captureService.$isShowingFullscreenControls.values {
                withAnimation {
                    // Prefer showing a minimized UI when capture controls enter a fullscreen appearance.
                    prefersMinimizedUI = isShowingFullscreenControls
                }
            }
        }
    }
}
