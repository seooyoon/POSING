/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A protocol that represents the model for the camera view.
*/

import SwiftUI

/// A protocol that represents the model for the camera view.
///
/// The AVFoundation camera APIs require running on a physical device. The app defines the model as a protocol to make it
/// simple to swap out the real camera for a test camera when previewing SwiftUI views.
@MainActor
protocol Camera: AnyObject, SendableMetatype {

    /// Provides the current status of the camera.
    var status: CameraStatus { get }

    /// The camera's current activity state, which can be photo capture, movie capture, or idle.
    var captureActivity: CaptureActivity { get }

    /// The source of video content for a camera preview.
    var previewSource: PreviewSource { get }
    
    /// Starts the camera capture pipeline.
    func start() async

    /// The capture mode, which can be photo or video.
    var captureMode: CaptureMode { get set }
    
    /// A Boolean value that indicates whether the camera is currently switching capture modes.
    var isSwitchingModes: Bool { get }
    
    /// A Boolean value that indicates whether the camera prefers showing a minimized set of UI controls.
    var prefersMinimizedUI: Bool { get }

    /// Switches between video devices available on the host system.
    func switchVideoDevices() async
    
    /// A Boolean value that indicates whether the camera is currently switching video devices.
    var isSwitchingVideoDevices: Bool { get }
    
    /// Performs a one-time automatic focus and exposure operation.
    func focusAndExpose(at point: CGPoint) async

    /// 길게 누른 자리에 초점 · 노출을 맞추고 잠금
    func lockFocusAndExposure(at point: CGPoint) async

    /// 밝기(노출 보정, EV) 설정
    func setExposureBias(_ bias: Float) async
    
    /// A Boolean value that indicates whether to capture Live Photos when capturing stills.
    var isLivePhotoEnabled: Bool { get set }
    
    /// A value that indicates how to balance the photo capture quality versus speed.
    var qualityPrioritization: QualityPrioritization { get set }
    
    /// Captures a photo and writes it to the user's photo library.
    func capturePhoto() async

    /// 셔터: 타이머가 켜져 있으면 카운트다운 뒤 촬영, 카운트다운 중에 누르면 취소
    func shutterPressed() async

    /// 플래시 (자동 → 켬 → 끔). 비디오 모드에서는 조명
    var flashMode: FlashMode { get set }

    /// 타이머 (끔 → 3 → 5 → 10초)
    var timerDuration: TimerDuration { get set }

    /// 타이머 남은 초. 카운트다운 중이 아니면 nil
    var countdown: Int? { get }

    /// 더보기 메뉴 노출 (±2, 전체 밝기 고정)
    var exposureCompensation: Float { get set }

    /// 전면 화면 플래시 중 (화면 전체를 하얗게)
    var isScreenFlashing: Bool { get }

    /// 사진 비율 (4:3 → 16:9 → 1:1)
    var photoAspect: PhotoAspect { get set }

    /// 고른 카메라의 색감 (셔터 왼쪽 카메라 버튼). 사진에만 적용
    var cameraLook: CameraLook { get set }

    /// 고른 사진 형식 (JPEG · RAW). 실제로 찍히는 값은 `activeCodec`
    var photoCodec: PhotoCodec { get set }

    /// 지금 카메라가 RAW(Apple ProRAW)를 찍을 수 있음
    var isRAWSupported: Bool { get }

    /// 장면이 어두움 (어둡거나 렌즈를 가림). 하단 조작부 모양에 씀
    var isSceneDark: Bool { get }

    /// 고른 사진 해상도(MP). 실제로 찍히는 값은 `activeResolution`
    var photoResolution: Int { get set }

    /// 지금 카메라가 찍을 수 있는 해상도(MP, 작은 것부터)
    var availableResolutions: [Int] { get }
    
    /// 비디오 해상도 · 프레임률
    var videoMode: VideoMode { get set }

    /// 슬로 모션 프레임률
    var slowMotionFrameRate: Int { get set }

    /// 지금 카메라가 찍을 수 있는 조합. 비어 있으면 아직 모름 (모두 누를 수 있게 둠)
    var availableVideoModes: Set<VideoMode> { get }
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins.
    var shouldFlashScreen: Bool { get }
    
    /// A Boolean that indicates whether the camera supports HDR video recording.
    var isHDRVideoSupported: Bool { get }

    /// 렌즈에 얼룩이 감지됨 (iOS 26 렌즈 얼룩 감지)
    var isLensSmudged: Bool { get }

    /// 배율 버튼 · 다이얼 · 접사 상태
    var zoom: ZoomState { get }

    /// 표시 배율 설정 (0.5×~25×)
    func setZoom(_ displayFactor: CGFloat, animated: Bool) async

    /// 꽃 버튼: 자동 접사 전환 켜기/끄기
    func setAutoMacroEnabled(_ isEnabled: Bool) async

    /// 전면 화각 버튼: 넓게 ↔ 가깝게
    func setFrontWide(_ isWide: Bool) async
    
    /// A Boolean value that indicates whether camera enables HDR video recording.
    var isHDRVideoEnabled: Bool { get set }
    
    /// Starts or stops recording a movie, and writes it to the user's photo library when complete.
    func toggleRecording() async
    
    /// A thumbnail image for the most recent photo or video capture.
    var thumbnail: CGImage? { get }
    
    /// An error if the camera encountered a problem.
    var error: Error? { get }
    
    /// Synchronize the state of the camera with the persisted values.
    func syncState() async
}

extension Camera {
    /// LIVE를 쓸 수 있는지. 비율이 4:3이 아니거나 기본이 아닌 카메라(CLAUDE.md 6절), RAW면 자동 끔
    var isLivePhotoAvailable: Bool {
        photoAspect == .fourThree && activeCodec != .raw
            && (cameraLook.isDefault || !AppDefaults.turnsOffLiveForNonDefaultCamera)
    }

    /// 실제로 LIVE로 찍히는지
    var isLivePhotoActive: Bool {
        isLivePhotoEnabled && isLivePhotoAvailable && activeResolution <= PhotoResolution.maxWithLivePhoto
    }

    /// 실제로 찍히는 형식: RAW를 골랐어도 지금 카메라가 지원하지 않으면 JPEG (사진을 놓치지 않게)
    var activeCodec: PhotoCodec {
        photoCodec == .raw && isRAWSupported ? .raw : .jpeg
    }

    /// 실제로 찍히는 해상도: 고른 값 이하에서 가장 큰 값 (전면 등 지원하지 않으면 낮아짐)
    var activeResolution: Int {
        availableResolutions.last { $0 <= photoResolution } ?? availableResolutions.first ?? photoResolution
    }
}

extension Camera {
    /// 실제로 찍히는 비디오 조합 (지금 카메라에 없는 값이면 대신 찍을 값)
    var activeVideoMode: VideoMode { videoMode.resolved(in: availableVideoModes) }

    /// 실제로 찍히는 슬로 모션 프레임률
    var activeSlowMotionFrameRate: Int {
        VideoMode(resolution: .hd, frameRate: slowMotionFrameRate).resolved(in: availableVideoModes).frameRate
    }

    func isVideoModeAvailable(_ mode: VideoMode) -> Bool {
        availableVideoModes.isEmpty || availableVideoModes.contains(mode)
    }
}
