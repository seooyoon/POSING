/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Extensions on AVFoundation capture and related types.
*/

import AVFoundation

extension AVCaptureDevice {
    /// 지금 노출 값으로 계산한 장면 밝기 (EV100). 어두울수록 낮음.
    /// 노출을 잠가도 렌즈를 가린 것을 알 수 있게 측광 차이를 더함
    var sceneEV: Double {
        log2(Double(lensAperture * lensAperture) / exposureDuration.seconds)
            - log2(Double(iso) / 100)
            + Double(exposureTargetOffset)
    }
}

extension CMVideoDimensions: @retroactive Equatable, @retroactive Comparable {
    
    static let zero = CMVideoDimensions()
    
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    public static func < (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width < rhs.width && lhs.height < rhs.height
    }
}

extension AVCaptureDevice {
    var activeFormat10BitVariant: AVCaptureDevice.Format? {
        formats.filter {
            $0.maxFrameRate == activeFormat.maxFrameRate &&
            $0.formatDescription.dimensions == activeFormat.formatDescription.dimensions
        }
        .first(where: { $0.isTenBitFormat })
    }
}

extension AVCaptureDevice {
    /// 해상도 · 프레임률에 맞는 형식. 10비트(HDR)를 원하면 먼저 찾고, 손떨림 보정이 강한 형식을 고름
    func format(for mode: VideoMode, prefersTenBit: Bool) -> AVCaptureDevice.Format? {
        let matches = formats.filter { $0.supports(mode) }
        let preferred = matches.filter { $0.isTenBitFormat == prefersTenBit }
        let candidates = preferred.isEmpty ? matches : preferred
        return candidates.first { $0.isVideoStabilizationModeSupported(.cinematicExtended) } ?? candidates.first
    }

    /// 이 카메라가 찍을 수 있는 조합
    var supportedVideoModes: Set<VideoMode> {
        var modes = Set<VideoMode>()
        for resolution in VideoResolution.allCases {
            for frameRate in VideoMode.frameRates + VideoMode.slowMotionFrameRates {
                let mode = VideoMode(resolution: resolution, frameRate: frameRate)
                if formats.contains(where: { $0.supports(mode) }) { modes.insert(mode) }
            }
        }
        return modes
    }
}

extension AVCaptureDevice.Format {
    func supports(_ mode: VideoMode) -> Bool {
        formatDescription.dimensions == mode.resolution.dimensions
            && videoSupportedFrameRateRanges.contains { $0.minFrameRate <= Double(mode.frameRate) && Double(mode.frameRate) <= $0.maxFrameRate }
    }

    var isTenBitFormat: Bool {
        formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    }
    var maxFrameRate: Double {
        videoSupportedFrameRateRanges.last?.maxFrameRate ?? 0
    }
}

