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
    var captureActivity = CaptureActivity.idle
    
    /// A Boolean value that indicates whether the app is currently switching video devices.
    private(set) var isSwitchingVideoDevices = false
    
    /// A Boolean value that indicates whether the camera prefers showing a minimized set of UI controls.
    var prefersMinimizedUI = false
    
    /// A Boolean value that indicates whether the app is currently switching capture modes.
    private(set) var isSwitchingModes = false
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins.
    private(set) var shouldFlashScreen = false
    
    /// A thumbnail for the last captured photo or video.
    var thumbnail: CGImage?
    
    /// An error that indicates the details of an error during photo or movie capture.
    private(set) var error: Error?
    
    /// An object that provides the connection between the capture session and the video preview layer.
    var previewSource: PreviewSource { captureService.previewSource }
    
    /// A Boolean that indicates whether the camera supports HDR video recording.
    var isHDRVideoSupported = false

    var isLensSmudged = false

    var zoom = ZoomState.unavailable

    private let captureTimer = CaptureTimer()
    var countdown: Int? { captureTimer.countdown }

    private(set) var isScreenFlashing = false
    /// 지금 카메라의 사진 출력이 플래시를 지원
    private var isFlashSupported = false
    /// 지금 카메라가 찍을 수 있는 사진 크기
    private var photoDimensions: [CMVideoDimensions] = []
    /// 지금 카메라가 찍을 수 있는 MP
    private var deviceResolutions: [Int] = []
    /// 고를 수 있는 MP. RAW는 24MP가 없음
    var availableResolutions: [Int] {
        PhotoResolution.selectable(from: deviceResolutions, codec: activeCodec)
    }
    private(set) var isRAWSupported = false
    var sceneBrightness = SceneBrightness()
    var isSceneDark: Bool { sceneBrightness.isDark }
    /// 지금 찍는 촬영 (플래시 포함). 이 동안 누른 셔터는 기본 카메라처럼 무시
    private var shutterOwner: UUID?

    /// 해당 촬영이 아직 셔터를 잡고 있을 때만 풂 (앞 촬영이 늦게 끝나도 다음 촬영을 풀지 않게)
    /// 이 촬영이 아직 셔터를 쥐고 있을 때만 셔터를 풀고 화면 플래시를 끔 (다음 촬영의 플래시를 끄지 않게)
    private func releaseShutter(_ owner: UUID, hidesScreenFlash: Bool) {
        guard shutterOwner == owner else { return }
        shutterOwner = nil
        if hidesScreenFlash { hideScreenFlash() }
    }
    
    /// An object that saves captured media to a person's Photos library.
    let mediaLibrary = MediaLibrary()
    
    /// An object that manages the app's capture functionality.
    let captureService = CaptureService()
    
    /// Persistent state shared between the app and capture extension.
    var cameraState = CameraState()
    
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
            // 앱을 처음 열면 마지막 모드와 상관없이 항상 사진 (세션 시작 전이라 didSet은 세션을 건드리지 않음)
            captureMode = .photo
            cameraState.captureMode = .photo
            // 마지막 형식이 RAW면 세션을 시작하기 전에 준비
            await captureService.setRAWEnabled(photoCodec == .raw)
            // Start the capture service to start the flow of data.
            try await captureService.start(with: cameraState)
            observeState()
            status = .running
            updateTorch()
            updatePreviewFilter()
            observePreviewFilterInputs()
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
            captureTimer.cancel()
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                // Update the configuration of the capture service for the new mode.
                try? await captureService.setCaptureMode(captureMode)
                // Update the persistent state value.
                cameraState.captureMode = captureMode
                updateTorch()
                updatePreviewFilter()
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
        guard !isSwitchingVideoDevices, shutterOwner == nil else { return }
        let owner = UUID()
        shutterOwner = owner
        // 전면 카메라가 플래시를 지원하지 않으면 촬영 순간 화면을 하얗게 밝혀 대신함
        let usesScreenFlash = zoom.isFrontCamera && !isFlashSupported && flashMode == .on
        if usesScreenFlash {
            await showScreenFlash()
        }
        do {
            let appliesPhotoFilters = activeCodec != .raw && !isLivePhotoActive
            let photoFeatures = PhotoFeatures(isLivePhotoEnabled: isLivePhotoActive,
                                              qualityPrioritization: qualityPrioritization,
                                              flashMode: AVCaptureDevice.FlashMode(flashMode),
                                              // RAW(DNG)는 자를 수 없어 원본 4:3으로 저장
                                              cropRatio: activeCodec == .raw ? nil : photoAspect.cropLongToShort,
                                              // RAW(DNG)와 LIVE는 색감 · 스타일을 입히지 않음 (LIVE 영상 부분은 보정할 수 없어 짝이 어긋남)
                                              lookLUTURL: appliesPhotoFilters ? cameraLook.lutURL : nil,
                                              style: appliesPhotoFilters && photoStyle.changesImage ? photoStyle : nil,
                                              isRAW: activeCodec == .raw,
                                              maxDimensions: activeDimensions)
            let photo = try await captureService.capturePhoto(with: photoFeatures) { [weak self] in
                // 찍기를 마치면 처리 · 저장이 끝나기 전이라도 다음 셔터를 받음
                Task { @MainActor in self?.releaseShutter(owner, hidesScreenFlash: usesScreenFlash) }
            }
            releaseShutter(owner, hidesScreenFlash: usesScreenFlash)
            try await mediaLibrary.save(photo: photo)
        } catch {
            releaseShutter(owner, hidesScreenFlash: usesScreenFlash)
            self.error = error
        }
    }

    func shutterPressed() async {
        guard shutterOwner == nil else { return }
        await captureTimer.shutterPressed(duration: timerDuration) { [weak self] in
            await self?.capturePhoto()
        }
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

    /// 앱을 켜면 항상 4:3으로 시작 (저장하지 않음)
    var photoAspect = PhotoAspect.fourThree
    var cameraLook = CameraLookLibrary.startLook()
    var photoStyle = StyleSelection.standard

    /// 저장본에 들어가는 보정과 같은 조건 (RAW · LIVE면 보정 없음)
    private var previewFilterInputs: (lutURL: URL?, style: StyleSelection?) {
        guard captureMode == .photo, activeCodec != .raw, !isLivePhotoActive else { return (nil, nil) }
        return (cameraLook.lutURL, photoStyle)
    }

    /// 사진 모드에서 카메라 색감 · 스타일 보정이 있으면 미리보기에도 보정 표시 (Metal 미리보기)
    private func updatePreviewFilter() {
        guard status == .running else { return }
        let inputs = previewFilterInputs
        captureService.previewSource.filteredFeed.configure(lutURL: inputs.lutURL, style: inputs.style)
        Task { await captureService.refreshPreviewFiltering() }
    }

    /// 색감 · 스타일 · 형식 · LIVE · 비율 · 해상도 등 보정 조건이 바뀌면 미리보기 다시 맞춤
    private func observePreviewFilterInputs() {
        withObservationTracking {
            _ = previewFilterInputs
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updatePreviewFilter()
                self?.observePreviewFilterInputs()
            }
        }
    }

    var photoCodec = PhotoCodec.saved {
        didSet {
            photoCodec.save()
            guard photoCodec != oldValue else { return }
            // RAW는 48MP로, JPEG로 돌아오면 기본 해상도로
            photoResolution = photoCodec == .raw ? PhotoResolution.values.last ?? 48 : AppDefaults.photoResolution
            let isRAW = photoCodec == .raw
            Task { await captureService.setRAWEnabled(isRAW) }
        }
    }

    var videoMode = VideoMode.saved {
        didSet {
            videoMode.save()
            guard videoMode != oldValue, status == .running else { return }
            // 형식을 바꾸는 동안 미리보기를 흐리게 (모드 전환과 같음)
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                await captureService.setVideoMode(videoMode)
            }
        }
    }

    var availableVideoModes = Set<VideoMode>()

    var slowMotionFrameRate = VideoMode.savedSlowMotionFrameRate {
        didSet {
            VideoMode.saveSlowMotionFrameRate(slowMotionFrameRate)
            guard slowMotionFrameRate != oldValue, status == .running else { return }
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                await captureService.setSlowMotionFrameRate(slowMotionFrameRate)
            }
        }
    }

    var photoResolution = PhotoResolution.saved {
        didSet {
            PhotoResolution.save(photoResolution)
            // LIVE를 켠 채 48MP를 고르면 LIVE를 끔
            if photoCodec != .raw, photoResolution > PhotoResolution.maxWithLivePhoto, isLivePhotoEnabled {
                isLivePhotoEnabled = false
            }
        }
    }

    /// 고른 해상도에 맞는 장치 사진 크기
    private var activeDimensions: CMVideoDimensions? {
        photoDimensions.last {
            PhotoResolution.megapixels(width: $0.width, height: $0.height) == activeResolution
        }
    }

    /// 비디오 모드에서만 플래시 값대로 조명을 켬
    private func updateTorch() {
        let mode = captureMode.isMovie ? flashMode : .off
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
            // 기본 카메라처럼 48MP에서 LIVE를 켜면 24MP로
            if isLivePhotoEnabled, photoCodec != .raw, photoResolution > PhotoResolution.maxWithLivePhoto {
                photoResolution = PhotoResolution.maxWithLivePhoto
            }
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

    func setOutsideBackdropVisible(_ isVisible: Bool) async {
        await captureService.setUltraWideBackdropActive(isVisible)
    }

    func lockFocusAndExposure(at point: CGPoint) async {
        await captureService.lockFocusAndExposure(at: point)
    }

    func setExposureBias(_ bias: Float) async {
        await captureService.setExposureBias(bias)
    }
    
    /// Sets the `showCaptureFeedback` state to indicate that capture is underway.
    func flashScreen() {
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
    func applyPhotoCapabilities(_ capabilities: CaptureCapabilities) {
        guard captureMode == .photo else { return }
        isFlashSupported = capabilities.isFlashSupported
        photoDimensions = capabilities.photoDimensions
        deviceResolutions = PhotoResolution.available(in: capabilities.photoDimensions)
        isRAWSupported = capabilities.isRAWSupported
    }
}
