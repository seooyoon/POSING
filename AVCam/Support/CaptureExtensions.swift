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

extension AVCaptureDevice.Format {
    var isTenBitFormat: Bool {
        formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    }
    var maxFrameRate: Double {
        videoSupportedFrameRateRanges.last?.maxFrameRate ?? 0
    }
}

