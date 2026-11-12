/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Supporting data types for the app.
*/

import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera.
enum CameraStatus {
    /// The initial status upon creation.
    case unknown
    /// A status that indicates a person disallows access to the camera or microphone.
    case unauthorized
    /// A status that indicates the camera failed to start.
    case failed
    /// A status that indicates the camera is successfully running.
    case running
    /// A status that indicates higher-priority media processing is interrupting the camera.
    case interrupted
}

/// An enumeration that defines the activity states the capture service supports.
///
/// This type provides feedback to the UI regarding the active status of the `CaptureService` actor.
enum CaptureActivity {
    case idle
    /// A status that indicates the capture service is performing photo capture.
    case photoCapture(willCapture: Bool = false, isLivePhoto: Bool = false)
    /// A status that indicates the capture service is performing movie capture.
    case movieCapture(duration: TimeInterval = 0.0)
    
    var isLivePhoto: Bool {
        if case .photoCapture(_, let isLivePhoto) = self {
            return isLivePhoto
        }
        return false
    }
    
    var willCapture: Bool {
        if case .photoCapture(let willCapture, _) = self {
            return willCapture
        }
        return false
    }
    
    var currentTime: TimeInterval {
        if case .movieCapture(let duration) = self {
            return duration
        }
        return .zero
    }
    
    var isRecording: Bool {
        if case .movieCapture = self {
            return true
        }
        return false
    }
}

/// An enumeration of the capture modes that the camera supports.
enum CaptureMode: String, Identifiable, CaseIterable, Codable {
    var id: Self { self }
    /// A mode that enables photo capture.
    case photo
    /// A mode that enables video capture.
    case video
    /// 슬로 모션 (HD 120 · 240fps)
    case slowMotion
    /// 타임랩스
    case timelapse

    /// 영상을 찍는 모드
    var isMovie: Bool { self != .photo }
    
    var systemName: String {
        switch self {
        case .photo:
            "camera.fill"
        case .video, .slowMotion, .timelapse:
            "video.fill"
        }
    }
}

/// A structure that represents a captured photo.
struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
    let livePhotoMovieURL: URL?
}

/// A structure that contains the uniform type identifier and movie URL.
struct Movie: Sendable {
    /// The temporary location of the file on disk.
    let url: URL
}

/// 사진 스타일 (docs/01_SPEC.md 8절). 순서는 기본 카메라와 같게 고정 (표준 왼쪽은 색조, 오른쪽 뉴트럴 다음부터 무드)
enum PhotoStyle: String, CaseIterable, Codable, Sendable {
    case coolRose, bright, roseGold, gold, amber, standard, neutral
    case luminous, natural, radiant, dramatic, quiet, cozy, elegant, softMono, starkMono
}

/// 스타일 하나의 값. 톤 · 색상 -100~100, 팔레트 0~100
struct StyleValues: Equatable, Codable, Sendable {
    var tone: Double
    var color: Double
    var palette: Double
}

/// 고른 스타일과 그 값
struct StyleSelection: Equatable, Sendable {
    let style: PhotoStyle
    let values: StyleValues
}

/// 저장 사진에 입힐 카메라 색감 (CameraLook에서 만듦)
struct PhotoLook: Sendable {
    /// 기본 색감 (.cube)
    let lutURL: URL?
    /// 플래시가 터진 사진에 쓰는 색감. 없으면 `lutURL`
    let flashLUTURL: URL?
    /// 디카 질감 · 플래시 사람 밝게
    let finish: CameraFinish?
}

/// 카메라별 디카 질감 값 (`camera_XX_이름.json`). 빠진 값은 0 / 끔
struct CameraFinish: Equatable, Sendable, Decodable {
    /// 살짝 부드럽게: 짧은 변 1000픽셀 기준 흐림 반경 (0 = 그대로)
    var softness: Double = 0
    /// 고운 노이즈 세기 (0 = 없음)
    var grain: Double = 0
    /// 가장자리 어둡게 0~1 (0 = 없음)
    var vignette: Double = 0
    /// 아이폰 자동 보정(여러 장 합성)을 줄임: 빠른 처리 우선으로 찍음
    var prefersFastProcessing = false
    /// 플래시 사진에서 사람 밝기 (EV, 양수 = 밝게)
    var flashSubjectEV: Double = 0
    /// 플래시 사진에서 배경 밝기 (EV, 음수 = 어둡게)
    var flashBackgroundEV: Double = 0

    var hasTexture: Bool { softness > 0 || grain > 0 || vignette > 0 }
    var hasFlashFalloff: Bool { flashSubjectEV != 0 || flashBackgroundEV != 0 }

    private enum CodingKeys: String, CodingKey {
        case softness, grain, vignette, prefersFastProcessing, flashSubjectEV, flashBackgroundEV
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        softness = try values.decodeIfPresent(Double.self, forKey: .softness) ?? 0
        grain = try values.decodeIfPresent(Double.self, forKey: .grain) ?? 0
        vignette = try values.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        prefersFastProcessing = try values.decodeIfPresent(Bool.self, forKey: .prefersFastProcessing) ?? false
        flashSubjectEV = try values.decodeIfPresent(Double.self, forKey: .flashSubjectEV) ?? 0
        flashBackgroundEV = try values.decodeIfPresent(Double.self, forKey: .flashBackgroundEV) ?? 0
    }

    /// json을 못 읽으면 nil (질감 없음)
    init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url),
              let finish = try? JSONDecoder().decode(CameraFinish.self, from: data) else { return nil }
        self = finish
    }
}

struct PhotoFeatures {
    let isLivePhotoEnabled: Bool
    let qualityPrioritization: QualityPrioritization
    let flashMode: AVCaptureDevice.FlashMode
    /// 저장 전에 가운데를 잘라낼 비율 (긴 변 / 짧은 변). nil이면 원본 4:3
    let cropRatio: CGFloat?
    /// 저장 전에 입힐 카메라 색감 (LUT · 플래시 LUT · 디카 질감). nil이면 보정 없음
    let look: PhotoLook?
    /// 저장 전에 입힐 스타일. nil이면 보정 없음
    let style: StyleSelection?
    /// RAW(Apple ProRAW)로 찍음. 아니면 JPEG
    let isRAW: Bool
    /// 사진 크기. nil이면 출력 최대 크기
    let maxDimensions: CMVideoDimensions?
}

/// 비디오 해상도
enum VideoResolution: String, CaseIterable, Sendable {
    case hd, uhd

    var label: String { self == .hd ? "HD" : "4K" }

    var dimensions: CMVideoDimensions {
        self == .hd ? CMVideoDimensions(width: 1920, height: 1080) : CMVideoDimensions(width: 3840, height: 2160)
    }
}

/// 비디오 해상도 + 프레임률 조합
struct VideoMode: Hashable, Sendable {
    /// 고를 수 있는 프레임률
    static let frameRates = [24, 30, 60]
    /// 슬로 모션 프레임률 (해상도는 HD)
    static let slowMotionFrameRates = [120, 240]

    var resolution: VideoResolution
    var frameRate: Int

    /// 이 카메라에서 실제로 찍을 조합. 안 되면 같은 해상도의 더 낮은 프레임률, 그래도 없으면 가장 가까운 값.
    /// 목록이 비어 있으면 아직 모르는 것이라 그대로
    func resolved(in available: Set<VideoMode>) -> VideoMode {
        guard !available.isEmpty, !available.contains(self) else { return self }
        let sameResolution = available.filter { $0.resolution == resolution }
        let candidates = sameResolution.isEmpty ? available : sameResolution
        return candidates.filter { $0.frameRate <= frameRate }.max { $0.frameRate < $1.frameRate }
            ?? candidates.min { $0.frameRate < $1.frameRate }
            ?? self
    }
}

/// A structure that represents the capture capabilities of `CaptureService` in
/// its current configuration.
struct CaptureCapabilities {

    let isLivePhotoCaptureSupported: Bool
    let isHDRSupported: Bool
    /// 사진 출력이 플래시를 지원 (전면에서 지원하지 않으면 화면 플래시로 대신함)
    let isFlashSupported: Bool
    /// 지금 카메라가 찍을 수 있는 사진 크기 (작은 것부터)
    let photoDimensions: [CMVideoDimensions]
    /// 사진 출력이 Apple ProRAW를 지원
    let isRAWSupported: Bool
    /// 지금 카메라가 찍을 수 있는 비디오 해상도 · 프레임률 조합
    let videoModes: Set<VideoMode>
    
    init(isLivePhotoCaptureSupported: Bool = false,
         isHDRSupported: Bool = false,
         isFlashSupported: Bool = false,
         photoDimensions: [CMVideoDimensions] = [],
         isRAWSupported: Bool = false,
         videoModes: Set<VideoMode> = []) {
        self.isLivePhotoCaptureSupported = isLivePhotoCaptureSupported
        self.isHDRSupported = isHDRSupported
        self.isFlashSupported = isFlashSupported
        self.isRAWSupported = isRAWSupported
        self.photoDimensions = photoDimensions
        self.videoModes = videoModes
    }
    
    static let unknown = CaptureCapabilities()
}

enum QualityPrioritization: Int, Identifiable, CaseIterable, CustomStringConvertible, Codable {
    var id: Self { self }
    case speed = 1
    case balanced
    case quality
    var description: String {
        switch self {
        case.speed:
            return "Speed"
        case .balanced:
            return "Balanced"
        case .quality:
            return "Quality"
        }
    }
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case audioDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
    case deviceChangeFailed
}

protocol OutputService {
    associatedtype Output: AVCaptureOutput
    var output: Output { get }
    var captureActivity: CaptureActivity { get }
    var capabilities: CaptureCapabilities { get }
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension OutputService {
    func setVideoRotationAngle(_ angle: CGFloat) {
        // Set the rotation angle on the output object's video connection.
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    func updateConfiguration(for device: AVCaptureDevice) {}
}
