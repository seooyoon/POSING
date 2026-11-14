/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a capture session and its inputs and outputs.
*/

import Foundation
@preconcurrency import AVFoundation
import Combine

/// An actor that manages the capture pipeline, which includes the capture session, device inputs, and capture outputs.
/// The app defines it as an `actor` type to ensure that all camera operations happen off of the `@MainActor`.
actor CaptureService {
    
    /// A value that indicates whether the capture service is idle or capturing a photo or movie.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    /// A value that indicates the current capture capabilities of the service.
    @Published private(set) var captureCapabilities = CaptureCapabilities.unknown
    /// A Boolean value that indicates whether a higher priority event, like receiving a phone call, interrupts the app.
    @Published private(set) var isInterrupted = false
    /// A Boolean value that indicates whether the user enables HDR video capture.
    @Published var isHDRVideoEnabled = false
    /// A Boolean value that indicates whether capture controls are in a fullscreen appearance.
    @Published var isShowingFullscreenControls = false

    /// 배율 버튼 · 다이얼 · 접사 상태
    @Published private(set) var zoomState = ZoomState.unavailable
    private let zoomController = ZoomController()
    /// 노출 보정 · 비디오 조명
    private let lightController = LightController()

    /// 렌즈 얼룩 감지 결과 (iOS 26). 렌즈 · 형식이 지원하지 않으면 계속 false
    @Published private(set) var isLensSmudged = false
    
    /// A type that connects a preview destination with the capture session.
    nonisolated let previewSource: PreviewSource
    /// 보정 미리보기 프레임 출력 (사진 모드 + 보정이 있을 때만 세션에 붙음)
    private let filteredFeed = FilteredPreviewFeed()
    private var wantsPreviewFiltering = false
    
    // The app's capture session.
    private let captureSession = AVCaptureSession()
    
    // An object that manages the app's photo capture behavior.
    private let photoCapture = PhotoCapture()
    
    // An object that manages the app's video capture behavior.
    private let movieCapture = MovieCapture()
    private let timelapseCapture = TimelapseCapture()
    
    // An internal collection of output services.
    /// 비디오 해상도 · 프레임률
    private var videoMode = VideoMode.saved
    private var slowMotionFrameRate = VideoMode.savedSlowMotionFrameRate
    /// 녹화 중에 도착한 모드 변경
    private var pendingCaptureMode: CaptureMode?
    /// 녹화 중에 바뀐 해상도 · 프레임률이 있음
    private var needsVideoModeReapply = false

    /// 지금 녹화 중인 모드. 시작 · 정지 때 이 액터에서만 바꿈 (타이머가 메인에서 바꾸는 captureActivity를 읽지 않게)
    private var recordingMode: CaptureMode?

    private var isRecording: Bool { recordingMode != nil }

    private var outputServices: [any OutputService] { [photoCapture, movieCapture, timelapseCapture] }
    
    // The video input for the currently selected device camera.
    private var activeVideoInput: AVCaptureDeviceInput?
    
    // The mode of capture, either photo or video. Defaults to photo.
    private(set) var captureMode = CaptureMode.photo
    
    // An object the service uses to retrieve capture devices.
    private let deviceLookup = DeviceLookup()
    
    // An object that monitors the state of the system-preferred camera.
    private let systemPreferredCamera = SystemPreferredCameraObserver()
    
    // An object that monitors video device rotations.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    private var rotationObservers = [AnyObject]()
    
    // A Boolean value that indicates whether the actor finished its required configuration.
    private var isSetUp = false
    
    // A delegate object that responds to capture control activation and presentation events.
    private var controlsDelegate = CaptureControlsDelegate()
    
    // A map that stores capture controls by device identifier.
    private var controlsMap: [String: [AVCaptureControl]] = [:]
    
    // A serial dispatch queue to use for capture control actions.
    private let sessionQueue = DispatchSerialQueue(label: "com.example.apple-samplecode.AVCam.sessionQueue")
    
    // Sets the session queue as the actor's executor.
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        sessionQueue.asUnownedSerialExecutor()
    }
    
    init() {
        // Create a source object to connect the preview view with the capture session.
        previewSource = DefaultPreviewSource(session: captureSession, filteredFeed: filteredFeed)
    }
    
    // MARK: - Authorization
    /// A Boolean value that indicates whether a person authorizes this app to use
    /// device cameras and microphones. If they haven't previously authorized the
    /// app, querying this property prompts them for authorization.
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            // Determine whether a person previously authorized camera access.
            var isAuthorized = status == .authorized
            // If the system hasn't determined their authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }
    
    // MARK: - Capture session life cycle
    func start(with state: CameraState) async throws {
        // Set initial operating state.
        captureMode = state.captureMode
        isHDRVideoEnabled = state.isVideoHDREnabled
        
        // Exit early if not authorized or the session is already running.
        guard await isAuthorized, !captureSession.isRunning else { return }
        // Configure the session and start it.
        try setUpSession()
        captureSession.startRunning()
        // 세션이 오디오 설정을 다시 잡을 수 있어 시작한 뒤에도 한 번 더
        allowHapticsDuringRecording()
    }

    /// 마이크가 켜져 있어도 햅틱이 울리게 함 (기본값은 녹음 중 햅틱 차단)
    private func allowHapticsDuringRecording() {
        do {
            try AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            logger.error("Unable to allow haptics during recording. \(error)")
        }
    }
    
    // MARK: - Capture setup
    // Performs the initial capture session configuration.
    private func setUpSession() throws {
        // Return early if already set up.
        guard !isSetUp else { return }

        // Observe internal state and notifications.
        observeOutputServices()
        observeNotifications()
        observeCaptureControlsState()
        
        do {
            // Retrieve the default camera and microphone.
            let defaultCamera = try deviceLookup.defaultCamera
            let defaultMic = try deviceLookup.defaultMic

            // Enable using AirPods as a high-quality lapel microphone.
            captureSession.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true
            allowHapticsDuringRecording()

            // Add inputs for the default camera and microphone devices.
            activeVideoInput = try addInput(for: defaultCamera)
            try addInput(for: defaultMic)

            // Configure the session preset based on the current capture mode.
            captureSession.sessionPreset = captureMode == .photo ? .photo : .high
            if captureMode == .photo {
                selectHighResolutionPhotoFormat(for: defaultCamera)
            }

            // Deferred start brings up the preview first, and prepares the capture outputs a moment
            // later. An app that links the iOS 26 SDK gets this behavior by default; these
            // assignments show the properties that control it.
            captureSession.automaticallyRunsDeferredStart = true

            // Add the photo capture output as the default output type.
            photoCapture.output.isDeferredStartEnabled = photoCapture.output.isDeferredStartSupported
            try addOutput(photoCapture.output)
            // If the capture mode is set to `video`, add a movie capture output.
            if captureMode == .video {
                // Add the movie output as the default output type.
                movieCapture.output.isDeferredStartEnabled = movieCapture.output.isDeferredStartSupported
                try addOutput(movieCapture.output)
                setHDRVideoEnabled(isHDRVideoEnabled)
            }
            
            // 렌즈 얼룩 감지는 세션 시작 전에 켬
            enableLensSmudgeDetection(for: defaultCamera)
            updateOutputMirroring()
            zoomController.attach(to: defaultCamera)
            lightController.attach(to: defaultCamera)
            // Configure controls to use with the Camera Control.
            configureControls(for: defaultCamera)
            // Monitor the system-preferred camera state.
            monitorSystemPreferredCamera()
            // Configure a rotation coordinator for the default video device.
            createRotationCoordinator(for: defaultCamera)
            // Observe changes to the default camera's subject area.
            observeSubjectAreaChanges(of: defaultCamera)
            // Update the service's advertised capabilities.
            updateCaptureCapabilities()
            
            isSetUp = true
        } catch {
            throw CameraError.setupFailed
        }
    }

    // Adds an input to the capture session to connect the specified capture device.
    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }
    
    // Adds an output to the capture session to connect the specified capture device, if allowed.
    /// 이미 세션에 있으면 그대로 둠 (비디오 ↔ 슬로 모션)
    private func addOutputIfNeeded(_ output: AVCaptureOutput) throws {
        guard !captureSession.outputs.contains(output) else { return }
        try addOutput(output)
    }

    private func addOutput(_ output: AVCaptureOutput) throws {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw CameraError.addOutputFailed
        }
    }
    
    // The device for the active video input.
    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }
    
    // MARK: - Capture controls
    
    private func configureControls(for device: AVCaptureDevice) {
        
        // Exit early if the host device doesn't support capture controls.
        guard captureSession.supportsControls else { return }
        
        // Begin configuring the capture session.
        captureSession.beginConfiguration()
        
        // Remove previously configured controls, if any.
        for control in captureSession.controls {
            captureSession.removeControl(control)
        }
        
        // Create controls and add them to the capture session.
        for control in createControls(for: device) {
            if captureSession.canAddControl(control) {
                captureSession.addControl(control)
            } else {
                logger.info("Unable to add control \(control).")
            }
        }
        
        // Set the controls delegate.
        captureSession.setControlsDelegate(controlsDelegate, queue: sessionQueue)
        
        // Commit the capture session configuration.
        captureSession.commitConfiguration()
    }
    
    func createControls(for device: AVCaptureDevice) -> [AVCaptureControl] {
        // Retrieve the capture controls for this device, if they exist.
        guard let controls = controlsMap[device.uniqueID] else {
            // Define the default controls.
            var controls = [
                AVCaptureSystemZoomSlider(device: device),
                AVCaptureSystemExposureBiasSlider(device: device)
            ]
            // Create a lens position control if the device supports setting a custom position.
            if device.isLockingFocusWithCustomLensPositionSupported {
                // Create a slider to adjust the value from 0 to 1.
                let lensSlider = AVCaptureSlider("렌즈 위치", symbolName: "circle.dotted.circle", in: 0...1)
                // Perform the slider's action on the session queue.
                lensSlider.setActionQueue(sessionQueue) { lensPosition in
                    do {
                        try device.lockForConfiguration()
                        device.setFocusModeLocked(lensPosition: lensPosition)
                        device.unlockForConfiguration()
                    } catch {
                        logger.info("Unable to change the lens position: \(error)")
                    }
                }
                // Add the slider the controls array.
                controls.append(lensSlider)
            }
            // Store the controls for future use.
            controlsMap[device.uniqueID] = controls
            return controls
        }
        
        // Return the previously created controls.
        return controls
    }
    
    // MARK: - Capture mode selection
    
    /// Changes the mode of capture, which can be `photo` or `video`.
    ///
    /// - Parameter `captureMode`: The capture mode to enable.
    func setCaptureMode(_ captureMode: CaptureMode) throws {
        // 녹화 중에는 출력을 바꾸지 않음. 먼저 눌린 모드 변경이 늦게 도착하면 녹화가 끝난 뒤 적용
        guard !isRecording else {
            pendingCaptureMode = captureMode
            return
        }
        try applyCaptureMode(captureMode)
        // 프리셋 · 형식이 바뀌면 장치 배율이 0.5×로 돌아가므로 기본 배율(1×)로
        zoomController.applyDefaultZoom()
        // 화면의 초점 표시가 지워지므로 장치 잠금 · 밝기도 같이 풀기
        resetFocusAndExposure()
        // 형식이 바뀌면 얼룩 감지가 꺼지므로, 새 형식이 적용된 뒤 다시 켬
        refreshLensSmudgeDetection()
    }

    /// 비디오 해상도 · 프레임률 변경. 녹화 중에는 바꾸지 않음 (화면에서도 판이 닫혀 있음)
    func setVideoMode(_ mode: VideoMode) {
        videoMode = mode
        guard captureMode == .video else { return }
        reapplyVideoMode()
    }

    /// 슬로 모션 프레임률 변경
    func setSlowMotionFrameRate(_ rate: Int) {
        slowMotionFrameRate = rate
        guard captureMode == .slowMotion else { return }
        reapplyVideoMode()
    }

    private func reapplyVideoMode() {
        // 파일을 마무리하는 동안 바뀐 값은 녹화가 끝난 뒤 적용
        guard !isRecording else {
            needsVideoModeReapply = true
            return
        }
        captureSession.beginConfiguration()
        applyVideoMode()
        updateCaptureCapabilities()
        captureSession.commitConfiguration()
        // 형식이 바뀌면 배율 · 얼룩 감지가 풀리므로 모드 전환 때와 같이 다시 맞춤
        zoomController.applyDefaultZoom()
        resetFocusAndExposure()
        refreshLensSmudgeDetection()
    }

    /// 고른 해상도 · 프레임률에 맞는 형식을 장치에 적용. 맞는 형식이 없으면 그대로
    private func applyVideoMode() {
        guard let mode = activeVideoMode else { return }
        let device = currentDevice
        // 이 카메라에 없는 조합이면 대신 찍을 값으로 (화면 표시도 같은 규칙)
        let resolved = mode.resolved(in: device.supportedVideoModes)
        // 10비트(HDR)는 일반 비디오만
        let prefersTenBit = isHDRVideoEnabled && captureMode == .video
        guard let format = device.format(for: resolved, prefersTenBit: prefersTenBit) else { return }
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(resolved.frameRate))
            // 최소가 최대를 넘지 않는 순서로 설정
            if duration > device.activeVideoMaxFrameDuration {
                device.activeVideoMaxFrameDuration = duration
                device.activeVideoMinFrameDuration = duration
            } else {
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("Unable to lock the device to apply the video mode.")
        }
    }

    /// 지금 모드에 쓸 해상도 · 프레임률. 사진은 없음
    private var activeVideoMode: VideoMode? {
        switch captureMode {
        case .photo: nil
        case .video: videoMode
        case .slowMotion: VideoMode(resolution: .hd, frameRate: slowMotionFrameRate)
        case .timelapse: VideoMode(resolution: .hd, frameRate: AppDefaults.timelapseFrameRate)
        }
    }

    private func applyCaptureMode(_ captureMode: CaptureMode) throws {
        // Update the internal capture mode value before performing the session configuration.
        self.captureMode = captureMode
        try configureOutputs(for: captureMode)
        // 사진 프리셋은 구성을 마칠 때 적용되므로, 그 뒤에 48MP 형식을 고름
        // (같은 구성 안에서 고르면 직전 비디오 형식을 기준으로 찾아 48MP를 놓침)
        if captureMode == .photo {
            applyHighResolutionPhotoFormat()
        }
    }

    private func configureOutputs(for captureMode: CaptureMode) throws {
        // Change the configuration atomically.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Configure the capture session for the selected capture mode.
        switch captureMode {
        case .photo:
            // The app needs to remove the movie capture output to perform Live Photo capture.
            captureSession.sessionPreset = .photo
            captureSession.removeOutput(movieCapture.output)
            captureSession.removeOutput(timelapseCapture.output)
            // 사진 처리 중이면 끝난 뒤 capturePhoto에서 맞춤
            if photosInProgress == 0 { updateFilteredPreviewOutput() }
        case .video, .slowMotion, .timelapse:
            captureSession.sessionPreset = .high
            if photosInProgress == 0 { updateFilteredPreviewOutput() }
            // 비디오 · 슬로 모션은 파일 출력, 타임랩스는 프레임 출력
            if captureMode == .timelapse {
                captureSession.removeOutput(movieCapture.output)
                try addOutputIfNeeded(timelapseCapture.output)
            } else {
                captureSession.removeOutput(timelapseCapture.output)
                try addOutputIfNeeded(movieCapture.output)
            }
            if isHDRVideoEnabled && captureMode == .video {
                setHDRVideoEnabled(true)
            }
            applyVideoMode()
            updateOutputMirroring()
            // 새로 붙인 출력도 지금 방향으로
            updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        }

        // Update the advertised capabilities after reconfiguration.
        updateCaptureCapabilities()
    }
    
    // MARK: - Device selection
    
    /// Changes the capture device that provides video input.
    ///
    /// The app calls this method in response to the user tapping the button in the UI to change cameras.
    /// The implementation switches between the front and back cameras and, in iPadOS,
    /// connected external cameras.
    func selectNextVideoDevice() {
        // The array of available video capture devices.
        let videoDevices = deviceLookup.cameras

        // Find the index of the currently selected video device.
        let selectedIndex = videoDevices.firstIndex(of: currentDevice) ?? 0
        // Get the next index.
        var nextIndex = selectedIndex + 1
        // Wrap around if the next index is invalid.
        if nextIndex == videoDevices.endIndex {
            nextIndex = 0
        }
        
        let nextDevice = videoDevices[nextIndex]
        // Change the session's active capture device.
        changeCaptureDevice(to: nextDevice)
        
        // The app only calls this method in response to the user requesting to switch cameras.
        // Set the new selection as the user's preferred camera.
        AVCaptureDevice.userPreferredCamera = nextDevice
    }
    
    /// 48MP 사진: 트리플 카메라 → 메인 렌즈 하나로, 끄면 다시 트리플 카메라로.
    /// 사용자가 고른 카메라(userPreferredCamera)는 바꾸지 않음 (앱을 다시 켜면 트리플 카메라)
    func setMainLensOnly(_ isOn: Bool) {
        guard let target = mainLensTarget(isOn) else { return }
        changeCaptureDevice(to: target)
        logger.notice("[48MP] main lens only: \(isOn, privacy: .public), photo max: \(self.photoCapture.output.maxPhotoDimensions.width, privacy: .public)")
    }

    /// 메인 렌즈 켜기 · 끄기로 카메라를 바꿔야 하는지 (화면 흐림 효과를 줄지 미리 확인)
    func needsMainLensChange(_ isOn: Bool) -> Bool {
        mainLensTarget(isOn) != nil
    }

    /// 메인 렌즈 켜기 · 끄기로 바꿀 카메라. 이미 맞으면 nil
    private func mainLensTarget(_ isOn: Bool) -> AVCaptureDevice? {
        let device = currentDevice
        guard device.position == .back else { return nil }
        if isOn {
            guard captureMode == .photo, device.isVirtualDevice else { return nil }
            return deviceLookup.mainBackCamera
        }
        guard !device.isVirtualDevice, let triple = deviceLookup.backCamera, triple != device else { return nil }
        return triple
    }

    // Changes the device the service uses for video capture.
    private func changeCaptureDevice(to device: AVCaptureDevice) {
        applyCaptureDevice(device)
        // 새 카메라 형식이 정해진 뒤 48MP 형식을 고름
        if captureMode == .photo {
            applyHighResolutionPhotoFormat()
        }
        // 새 카메라는 잠금 없이 연속 자동으로 시작
        resetFocusAndExposure()
        // 새 카메라 형식이 적용된 뒤 얼룩 감지를 다시 켬
        refreshLensSmudgeDetection()
    }

    private func applyCaptureDevice(_ device: AVCaptureDevice) {
        // The service must have a valid video input prior to calling this method.
        guard let currentInput = activeVideoInput else { fatalError() }
        
        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Remove the existing video input before attempting to connect a new one.
        captureSession.removeInput(currentInput)
        do {
            // Attempt to connect a new input and device to the capture session.
            activeVideoInput = try addInput(for: device)
            if captureMode != .photo {
                applyVideoMode()
            }
            zoomController.attach(to: device)
            lightController.attach(to: device)
            updateOutputMirroring()
            // Configure capture controls for new device selection.
            configureControls(for: device)
            // Configure a new rotation coordinator for the new device.
            createRotationCoordinator(for: device)
            // Register for device observations.
            observeSubjectAreaChanges(of: device)
            // Update the service's advertised capabilities.
            updateCaptureCapabilities()
        } catch {
            // Reconnect the existing camera on failure.
            captureSession.addInput(currentInput)
        }
    }
    
    /// Monitors changes to the system's preferred camera selection.
    ///
    /// iPadOS supports external cameras. When someone connects an external camera to their iPad,
    /// they're signaling the intent to use the device. The system responds by updating the
    /// system-preferred camera (SPC) selection to this new device. When this occurs, if the SPC
    /// isn't the currently selected camera, switch to the new device.
    private func monitorSystemPreferredCamera() {
        Task {
            // An object monitors changes to system-preferred camera (SPC) value.
            for await camera in systemPreferredCamera.changes {
                // If the SPC isn't the currently selected camera, attempt to change to that device.
                if let camera, currentDevice != camera {
                    logger.debug("Switching camera selection to the system-preferred camera.")
                    changeCaptureDevice(to: camera)
                }
            }
        }
    }
    
    // MARK: - Rotation handling
    
    /// Create a new rotation coordinator for the specified device and observe its state to monitor rotation changes.
    private func createRotationCoordinator(for device: AVCaptureDevice) {
        // Create a new rotation coordinator for this device.
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        
        // Set initial rotation state on the preview and output connections.
        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        
        // Cancel previous observations.
        rotationObservers.removeAll()
        
        // Add observers to monitor future changes.
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updatePreviewRotation(angle) }
            }
        )
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updateCaptureRotation(angle) }
            }
        )
    }
    
    private func updatePreviewRotation(_ angle: CGFloat) {
        // 보정 미리보기 프레임도 미리보기와 같은 방향
        if let connection = filteredFeed.output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        // 흐린 배경 층도 같은 방향
        let connections = captureSession.connections.filter { $0.videoPreviewLayer != nil }
        Task { @MainActor in
            // Set initial rotation angle on the video preview.
            connections.forEach { $0.videoRotationAngle = angle }
        }
    }
    
    private func updateCaptureRotation(_ angle: CGFloat) {
        // Update the orientation for all output services.
        // 타임랩스는 녹화 중 프레임 크기가 바뀌면 안 되므로 방향을 고정 (다음 녹화 시작 때 맞춤)
        let services: [any OutputService] = recordingMode == .timelapse ? [photoCapture, movieCapture] : outputServices
        services.forEach { $0.setVideoRotationAngle(angle) }
    }
    
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // Access the capture session's connected preview layer.
        guard let previewLayer = captureSession.connections.compactMap({ $0.videoPreviewLayer }).first else {
            fatalError("The app is misconfigured. The capture session should have a connection to a preview layer.")
        }
        return previewLayer
    }
    
    // MARK: - 배율 · 접사

    /// 표시 배율로 설정. 버튼은 부드럽게(animated), 다이얼 · 두 손가락은 바로
    func setZoom(_ displayFactor: CGFloat, animated: Bool) {
        zoomController.setZoom(displayFactor, animated: animated)
    }

    private func refreshZoom() {
        zoomController.refresh()
    }

    func setAutoMacroEnabled(_ isEnabled: Bool) {
        zoomController.setAutoMacroEnabled(isEnabled)
    }

    /// 꽃을 끈 동안 피사체가 멀어졌는지 확인 (장면 밝기와 같이 주기적으로)
    func refreshSubjectDistance() {
        zoomController.updateSubjectDistance()
    }

    func setFrontWide(_ isWide: Bool) {
        zoomController.setFrontWide(isWide)
    }

    // MARK: - 보정 미리보기

    /// 카메라 색감 · 스타일 보정이 있으면 미리보기 프레임 출력을 붙임.
    /// 호출 순서와 상관없이 피드의 지금 상태를 기준으로 맞춤
    func refreshPreviewFiltering() {
        wantsPreviewFiltering = filteredFeed.isFiltering
        // 사진 처리 중이면 끝난 뒤 맞춤 (세션 구성 변경과 겹치지 않게)
        guard photosInProgress == 0 else { return }
        updateFilteredPreviewOutput()
    }

    /// 사진 모드 + 보정일 때만 출력을 세션에 둠. 보정이 없으면 기존 미리보기만 씀 (성능 · 배터리)
    private func updateFilteredPreviewOutput() {
        let output = filteredFeed.output
        let shouldAttach = wantsPreviewFiltering && captureMode == .photo
        guard shouldAttach != captureSession.outputs.contains(output) else { return }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        guard shouldAttach else {
            captureSession.removeOutput(output)
            return
        }
        guard captureSession.canAddOutput(output) else {
            logger.error("Unable to add the filtered preview output.")
            return
        }
        captureSession.addOutput(output)
        updateOutputMirroring()
        if let rotationCoordinator {
            updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        }
    }

    // MARK: - 전면 카메라 좌우 반전

    /// 전면 카메라 사진 · 영상은 화면에 보인 그대로(거울 반전) 저장 (docs/02_UI.md 9절)
    private func updateOutputMirroring() {
        let isFront = currentDevice.position == .front
        for output in [photoCapture.output, movieCapture.output, timelapseCapture.output, filteredFeed.output] as [AVCaptureOutput] {
            guard let connection = output.connection(with: .video), connection.isVideoMirroringSupported else { continue }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFront
        }
    }

    // MARK: - 렌즈 얼룩 감지

    /// 얼룩 감지 간격. 계속 돌리면 배터리를 쓰므로 일정 간격으로만 (닦은 뒤에도 이 간격 안에 안내가 사라짐)
    private static let smudgeDetectionInterval = CMTime(seconds: AppDefaults.lensSmudgeDetectionInterval, preferredTimescale: 600)

    /// 지원하는 렌즈 · 형식이면 얼룩 감지를 켜고 결과를 관찰.
    /// begin/commitConfiguration 안이나 세션 시작 전에 불러야 함
    private func enableLensSmudgeDetection(for device: AVCaptureDevice) {
        // 카메라가 바뀌면 이전 카메라 결과는 버림
        if smudgeDevice !== device {
            smudgeObservation = nil
            smudgeDevice = nil
            clearLensSmudge()
        }
        guard device.activeFormat.isCameraLensSmudgeDetectionSupported else {
            // 이 형식(일부 비디오 형식 등)에서는 감지가 꺼지므로 안내도 숨김
            clearLensSmudge()
            return
        }
        // 이미 켜져 있으면 다시 켜지 않음 (켤 때마다 촬영 파이프라인이 오래 다시 구성되어 화면이 멈칫함)
        if !device.isCameraLensSmudgeDetectionEnabled {
            do {
                try device.lockForConfiguration()
                device.setCameraLensSmudgeDetectionEnabled(true, detectionInterval: Self.smudgeDetectionInterval)
                device.unlockForConfiguration()
            } catch {
                logger.debug("Unable to enable lens smudge detection. \(error)")
                return
            }
        }
        guard smudgeObservation == nil else { return }
        smudgeDevice = device
        // 알림마다 만든 작업은 순서가 바뀔 수 있어, 작업이 실행될 때 장치의 최신 결과를 다시 읽음
        smudgeObservation = device.observe(\.cameraLensSmudgeDetectionStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { await self?.updateLensSmudge() }
        }
    }
    private var smudgeObservation: NSKeyValueObservation?
    private var smudgeDevice: AVCaptureDevice?
    /// 얼룩이 처음 감지된 뒤 확인을 기다리는 중
    private var smudgeConfirmTask: Task<Void, Never>?

    /// 형식 · 카메라가 바뀐 뒤 감지가 꺼졌을 때만 구성 묶음 안에서 다시 켬
    private func refreshLensSmudgeDetection() {
        let device = currentDevice
        // 카메라가 바뀌면 지원 여부와 상관없이 이전 카메라 관찰 · 확인 대기를 먼저 정리
        if smudgeDevice !== device {
            smudgeObservation = nil
            smudgeDevice = nil
            clearLensSmudge()
        }
        let isSupported = device.activeFormat.isCameraLensSmudgeDetectionSupported
        guard isSupported, smudgeDevice !== device || !device.isCameraLensSmudgeDetectionEnabled else {
            if !isSupported { clearLensSmudge() }
            return
        }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        enableLensSmudgeDetection(for: device)
    }

    /// 한 번 감지된 것만으로는 띄우지 않고, 확인 시간 동안 계속 얼룩이면 안내 (잘못 뜨는 것을 줄임).
    /// 깨끗하다는 결과가 나오면 바로 숨김
    private func updateLensSmudge() {
        let status = smudgeDevice?.cameraLensSmudgeDetectionStatus ?? .disabled
        // 원인 확인용: 시스템 감지 결과 (0 꺼짐, 1 깨끗함, 2 얼룩, 3 판단 못 함)
        logger.notice("[Smudge] status \(status.rawValue)")
        switch status {
        case .smudged:
            guard !isLensSmudged, smudgeConfirmTask == nil else { return }
            smudgeConfirmTask = Task {
                try? await Task.sleep(for: .seconds(AppDefaults.lensSmudgeConfirmDelay))
                guard !Task.isCancelled else { return }
                smudgeConfirmTask = nil
                if smudgeDevice?.cameraLensSmudgeDetectionStatus == .smudged {
                    isLensSmudged = true
                }
            }
        // 깨끗함 · 꺼짐 · 판단 못 함(닦느라 움직이는 중 등)이면 숨김. 다시 얼룩이면 확인 뒤 다시 보임
        default:
            clearLensSmudge()
        }
    }

    private func clearLensSmudge() {
        smudgeConfirmTask?.cancel()
        smudgeConfirmTask = nil
        if isLensSmudged { isLensSmudged = false }
    }

    // MARK: - Automatic focus and exposure
    
    /// Performs a one-time automatic focus and expose operation.
    ///
    /// The app calls this method as the result of a person tapping on the preview area.
    func focusAndExpose(at point: CGPoint) {
        // The point this call receives is in view-space coordinates. Convert this point to device coordinates.
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        // 새로 탭하면 AE/AF 잠금은 풀림
        lockTask?.cancel()
        do {
            // Perform a user-initiated focus and expose.
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
        } catch {
            logger.debug("Unable to perform focus and exposure operation. \(error)")
        }
    }
    
    /// 길게 누른 자리에 초점 · 노출을 맞춘 뒤 잠금 (AE/AF 잠금)
    func lockFocusAndExposure(at point: CGPoint) {
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        lockTask?.cancel()
        do {
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
            // 잠근 뒤에는 피사체가 바뀌어도 자동으로 돌아가지 않음
            let device = currentDevice
            try device.lockForConfiguration()
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to lock focus and exposure. \(error)")
        }
        // 초점 · 노출이 맞춰질 시간을 두고 고정
        // 초점 · 노출 조정이 끝난 뒤에 고정 (장면마다 걸리는 시간이 달라 상태를 확인)
        lockTask = Task {
            let device = currentDevice
            // 조정이 시작되기를 잠깐 기다림 (이미 맞아 있으면 시작하지 않을 수 있음)
            for _ in 0..<6 where !(device.isAdjustingFocus || device.isAdjustingExposure) {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            // 시작된 조정이 끝날 때까지 기다림 (최대 2초)
            for _ in 0..<40 where device.isAdjustingFocus || device.isAdjustingExposure {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            guard !Task.isCancelled else { return }
            lockCurrentFocusAndExposure()
        }
    }
    private var lockTask: Task<Void, Never>?

    /// 모드 · 카메라 전환 시 AE/AF 잠금과 밝기를 풀고 연속 자동으로 되돌림
    private func resetFocusAndExposure() {
        lockTask?.cancel()
        do {
            try focusAndExpose(at: CGPoint(x: 0.5, y: 0.5), isUserInitiated: false)
        } catch {
            logger.debug("Unable to reset focus and exposure. \(error)")
        }
        // 초점 밝기만 풀고 더보기 메뉴 노출은 유지
        lightController.resetFocusBias()
    }

    private func lockCurrentFocusAndExposure() {
        let device = currentDevice
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to lock focus and exposure. \(error)")
        }
    }

    /// 초점 표시 옆 밝기
    func setExposureBias(_ bias: Float) {
        lightController.setFocusBias(bias)
    }

    /// 더보기 메뉴 노출 (전체 밝기 고정)
    func setExposureCompensation(_ value: Float) {
        lightController.setCompensation(value)
    }

    /// 비디오 모드 플래시 = 조명
    func setTorchMode(_ mode: FlashMode) {
        lightController.setTorch(AVCaptureDevice.TorchMode(mode))
    }

    // Observe notifications of type `subjectAreaDidChangeNotification` for the specified device.
    private func observeSubjectAreaChanges(of device: AVCaptureDevice) {
        // Cancel the previous observation task.
        subjectAreaChangeTask?.cancel()
        subjectAreaChangeTask = Task {
            // Signal true when this notification occurs.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.subjectAreaDidChangeNotification, object: device).compactMap({ _ in true }) {
                // Perform a system-initiated focus and expose.
                try? focusAndExpose(at: CGPoint(x: 0.5, y: 0.5), isUserInitiated: false)
            }
        }
    }
    private var subjectAreaChangeTask: Task<Void, Never>?
    
    private func focusAndExpose(at devicePoint: CGPoint, isUserInitiated: Bool) throws {
        // Configure the current device.
        let device = currentDevice
        
        // The following mode and point of interest configuration requires obtaining an exclusive lock on the device.
        try device.lockForConfiguration()
        
        let focusMode = isUserInitiated ? AVCaptureDevice.FocusMode.autoFocus : .continuousAutoFocus
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = focusMode
        }
        
        let exposureMode = isUserInitiated ? AVCaptureDevice.ExposureMode.autoExpose : .continuousAutoExposure
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = exposureMode
        }
        // Enable subject-area change monitoring when performing a user-initiated automatic focus and exposure operation.
        // If this method enables change monitoring, when the device's subject area changes, the app calls this method a
        // second time and resets the device to continuous automatic focus and exposure.
        device.isSubjectAreaChangeMonitoringEnabled = isUserInitiated
        
        // Release the lock.
        device.unlockForConfiguration()
        // 새로 탭하면 초점 밝기는 0에서 다시 시작 (기본 카메라와 동일). 더보기 메뉴 노출은 유지
        if isUserInitiated {
            lightController.resetFocusBias()
        }
    }
    
    // MARK: - Photo capture
    /// 처리가 끝나지 않은 사진 수
    private var photosInProgress = 0
    /// 사진 처리가 끝나면 적용할 RAW 설정
    private var pendingRAWEnabled: Bool?

    func capturePhoto(with features: PhotoFeatures, onCaptured: @escaping @Sendable () -> Void) async throws -> Photo {
        // RAW를 막 고르고 바로 찍어도 설정이 맞도록 촬영 직전에 확인
        if photoCapture.isRAWEnabled != features.isRAW {
            applyRAWEnabled(features.isRAW)
        }
        pendingRAWEnabled = nil
        photosInProgress += 1
        defer {
            photosInProgress -= 1
            // 처리 중이던 사진이 모두 끝난 뒤 미뤄 둔 RAW 설정을 적용
            if photosInProgress == 0, let pending = pendingRAWEnabled {
                pendingRAWEnabled = nil
                applyRAWEnabled(pending)
            }
            // 사진 처리 중에 미뤄 둔 보정 미리보기 출력도 맞춤
            if photosInProgress == 0 {
                updateFilteredPreviewOutput()
            }
        }
        let photo = try await photoCapture.capturePhoto(with: features, onCaptured: onCaptured)
        guard !photo.isProxy, features.cropRatio != nil || features.look != nil || features.style != nil else { return photo }
        var data = photo.data
        // 비율이 4:3이 아니면 가운데를 잘라 저장
        if let ratio = features.cropRatio {
            data = PhotoCropper.crop(data, longToShort: ratio)
        }
        // 자른 뒤 카메라 색감 → 스타일 → 디카 질감을 입힘
        if features.look != nil || features.style != nil {
            data = PhotoFilter.apply(look: features.look, style: features.style, to: data)
        }
        return Photo(data: data, isProxy: false, livePhotoMovieURL: nil)
    }

    /// RAW(Apple ProRAW) 촬영 준비를 켜고 끔 (세션 구성이 다시 일어남)
    func setRAWEnabled(_ isEnabled: Bool) {
        // 처리 중인 사진이 있으면 끝난 뒤로 미룸 (세션 구성 변경과 겹치지 않게)
        guard photosInProgress == 0 else {
            pendingRAWEnabled = isEnabled
            return
        }
        applyRAWEnabled(isEnabled)
    }

    private func applyRAWEnabled(_ isEnabled: Bool) {
        guard photoCapture.isRAWEnabled != isEnabled else { return }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        photoCapture.isRAWEnabled = isEnabled
    }

    /// 지금 카메라 노출로 계산한 장면 밝기
    var sceneEV: Double { currentDevice.sceneEV }

    // MARK: - Movie capture
    /// Starts recording video. The video records until the user stops recording,
    /// which calls the following `stopRecording()` method.
    func startRecording() {
        guard !isRecording else { return }
        if captureMode == .timelapse {
            // 녹화를 시작하기 직전의 방향으로 고정
            updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        }
        recordingMode = captureMode
        if captureMode == .timelapse {
            timelapseCapture.startRecording()
        } else {
            movieCapture.startRecording(isSlowMotion: captureMode == .slowMotion)
        }
    }

    /// Stops the recording and returns the captured movie.
    func stopRecording() async throws -> Movie {
        // 지금 녹화 중인 쪽을 멈춤
        let isTimelapse = recordingMode == .timelapse
        defer {
            recordingMode = nil
            if let mode = pendingCaptureMode {
                pendingCaptureMode = nil
                try? setCaptureMode(mode)
            }
            if needsVideoModeReapply {
                needsVideoModeReapply = false
                if captureMode.isMovie { reapplyVideoMode() }
            }
        }
        return isTimelapse ? try await timelapseCapture.stopRecording() : try await movieCapture.stopRecording()
    }

    /// 촬영 중 HDR 전환. 형식이 바뀌므로 렌즈 얼룩 감지를 다시 켠다
    func changeHDRVideo(_ isEnabled: Bool) {
        setHDRVideoEnabled(isEnabled)
        refreshLensSmudgeDetection()
    }

    /// Sets whether the app captures HDR video.
    func setHDRVideoEnabled(_ isEnabled: Bool) {
        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        // If the current device provides a 10-bit HDR format, enable it for use.
        // 직전 모드(슬로 모션 등) 형식이 아니라 지금 찍을 조합 기준으로 확인
        if isEnabled, let mode = activeVideoMode,
           currentDevice.format(for: mode.resolved(in: currentDevice.supportedVideoModes), prefersTenBit: true)?.isTenBitFormat == true {
            isHDRVideoEnabled = true
        } else {
            captureSession.sessionPreset = .high
            isHDRVideoEnabled = false
        }
        // 형식을 바꾸면 프레임 길이가 풀리므로 고른 프레임률까지 같이 적용
        applyVideoMode()
    }
    
    /// 구성 묶음을 따로 열어 48MP 형식을 고르고, 바뀐 해상도를 화면에 알림
    private func applyHighResolutionPhotoFormat() {
        captureSession.beginConfiguration()
        selectHighResolutionPhotoFormat(for: currentDevice)
        captureSession.commitConfiguration()
        updateCaptureCapabilities()
    }

    /// 사진 모드 프리셋(.photo) 형식이 48MP를 지원하지 않으면 48MP를 지원하는 형식으로 바꾼다
    /// (프리셋은 inputPriority가 됨). 같은 크기 · 픽셀 형식 → 같은 크기 → 같은 비율 순으로 찾고, 없으면 그대로
    private func selectHighResolutionPhotoFormat(for device: AVCaptureDevice) {
        let highResolutionArea = 40_000_000
        func maxPhotoArea(_ format: AVCaptureDevice.Format) -> Int {
            format.supportedMaxPhotoDimensions.map { Int($0.width) * Int($0.height) }.max() ?? 0
        }
        let current = device.activeFormat
        guard maxPhotoArea(current) < highResolutionArea else { return }
        let size = CMVideoFormatDescriptionGetDimensions(current.formatDescription)
        let pixelFormat = CMFormatDescriptionGetMediaSubType(current.formatDescription)
        let highResolution = device.formats.filter { maxPhotoArea($0) >= highResolutionArea && !$0.isTenBitFormat }
        func isSameSize(_ format: AVCaptureDevice.Format) -> Bool {
            let candidate = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return candidate.width == size.width && candidate.height == size.height
        }
        func isSameRatio(_ format: AVCaptureDevice.Format) -> Bool {
            let candidate = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(candidate.width) * Int(size.height) == Int(candidate.height) * Int(size.width)
        }
        let groups = [
            highResolution.filter { isSameSize($0) && CMFormatDescriptionGetMediaSubType($0.formatDescription) == pixelFormat },
            highResolution.filter(isSameSize),
            highResolution.filter(isSameRatio),
        ]
        guard let candidates = groups.first(where: { !$0.isEmpty }),
              let format = candidates.first(where: \.isHighestPhotoQualitySupported) ?? candidates.first else {
            return
        }
        logger.notice("[48MP] selected: \(Self.describe(format), privacy: .public)")
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.unlockForConfiguration()
        } catch {
            logger.error("Unable to select 48MP photo format. \(error)")
        }
    }

    /// 로그용 형식 설명: 크기 · 픽셀 형식 · 사진 최대 크기들
    private static func describe(_ format: AVCaptureDevice.Format) -> String {
        let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
        let code = String((0..<4).map { Character(UnicodeScalar(UInt8((subtype >> (24 - $0 * 8)) & 0xFF))) })
        let photos = format.supportedMaxPhotoDimensions.map { "\($0.width)x\($0.height)" }.joined(separator: ",")
        return "\(size.width)x\(size.height) \(code) photo[\(photos)]"
    }

    // MARK: - Internal state management
    /// Updates the state of the actor to ensure its advertised capabilities are accurate.
    ///
    /// When the capture session changes, such as changing modes or input devices, the service
    /// calls this method to update its configuration and capabilities. The app uses this state to
    /// determine which features to enable in the user interface.
    private func updateCaptureCapabilities() {
        // Update the output service configuration.
        outputServices.forEach { $0.updateConfiguration(for: currentDevice) }
        // Set the capture service's capabilities for the selected mode.
        switch captureMode {
        case .photo:
            captureCapabilities = photoCapture.capabilities
        case .video, .slowMotion:
            captureCapabilities = movieCapture.capabilities
        case .timelapse:
            captureCapabilities = timelapseCapture.capabilities
        }
    }
    
    /// Merge the `captureActivity` values of the photo and movie capture services,
    /// and assign the value to the actor's property.`
    private func observeOutputServices() {
        Publishers.Merge3(photoCapture.$captureActivity, movieCapture.$captureActivity, timelapseCapture.$captureActivity)
            .assign(to: &$captureActivity)
        zoomController.$state
            .assign(to: &$zoomState)
        // 배율 KVO는 액터 안에서 다시 읽음
        zoomController.onDeviceChange = { [weak self] in
            Task { await self?.refreshZoom() }
        }
    }
    
    /// Observe when capture control enter and exit a fullscreen appearance.
    private func observeCaptureControlsState() {
        controlsDelegate.$isShowingFullscreenControls
            .assign(to: &$isShowingFullscreenControls)
    }
    
    /// Observe capture-related notifications.
    private func observeNotifications() {
        Task {
            for await reason in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject? })
                .compactMap({ AVCaptureSession.InterruptionReason(rawValue: $0.integerValue) }) {
                /// Set the `isInterrupted` state as appropriate.
                isInterrupted = [.audioDeviceInUseByAnotherClient, .videoDeviceInUseByAnotherClient].contains(reason)
            }
        }
        
        Task {
            // Await notification of the end of an interruption.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                isInterrupted = false
            }
        }
        
        Task {
            for await error in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionErrorKey] as? AVError }) {
                // If the system resets media services, the capture session stops running.
                if error.code == .mediaServicesWereReset {
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                }
            }
        }
    }
}

class CaptureControlsDelegate: NSObject, AVCaptureSessionControlsDelegate {
    
    @Published private(set) var isShowingFullscreenControls = false

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        logger.debug("Capture controls active.")
    }

    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = true
        logger.debug("Capture controls will enter fullscreen appearance.")
    }
    
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = false
        logger.debug("Capture controls will exit fullscreen appearance.")
    }
    
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        logger.debug("Capture controls inactive.")
    }
}
