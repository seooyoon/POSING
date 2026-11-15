//
//  RAWDeveloper.swift
//  포징
//
//  POSING 사진 현상 (docs/05_TECH_NOTES.md 4-3절).
//  아이폰 부분 밝기 보정(어두운 곳 밝히기)을 빼고 RAW를 현상해, 디카처럼 대비 · 색이 살아 있는 사진을 만든다.
//  전체 밝기는 장면에 맞춰 자동으로, 노란 실내 조명은 디카 플래시처럼 중립 쪽으로. 기기 안에서만 처리 (오프라인).
//

import CoreImage
import Foundation
import ImageIO

enum RAWDeveloper {

    private static let context = CIContext()

    /// DNG 데이터 → 현상한 JPEG 데이터 (원본 메타데이터 유지, 방향은 이미 세움). 실패하면 nil
    static func develop(_ data: Data) -> Data? {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: nil) else { return nil }
        if filter.isLocalToneMapSupported {
            filter.localToneMapAmount = 0
        }
        neutralizeWarmLight(filter)
        filter.exposure = Float(autoExposure(filter))

        guard let image = filter.outputImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace),
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        // 현상 결과는 이미 똑바로 세워져 있음
        properties[kCGImagePropertyOrientation] = CGImagePropertyOrientation.up.rawValue
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = CGImagePropertyOrientation.up.rawValue
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        properties[kCGImagePropertyDNGDictionary] = nil
        properties[kCGImageDestinationLossyCompressionQuality] = RAWTuning.jpegQuality

        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return result as Data
    }

    // MARK: - 내부

    /// 따뜻한 조명(낮은 색온도)일수록 중립 쪽으로 당김. 디카 플래시가 실내 조명색을 덮는 느낌
    private static func neutralizeWarmLight(_ filter: CIRAWFilter) {
        let temperature = Double(filter.neutralTemperature)
        let gap = RAWTuning.neutralTemperature - temperature
        guard temperature > 0, gap > 0 else { return }
        let shift = min(gap * RAWTuning.warmthRemoval, RAWTuning.maxTemperatureShift)
        filter.neutralTemperature = Float(temperature - shift)
    }

    /// 작은 크기로 한 번 현상해 밝기 중앙값을 재고, 목표 밝기까지 올리는 EV (범위 제한)
    private static func autoExposure(_ filter: CIRAWFilter) -> Double {
        let original = filter.scaleFactor
        defer { filter.scaleFactor = original }
        let longSide = max(filter.nativeSize.width, filter.nativeSize.height)
        guard longSide > 0 else { return 0 }
        filter.scaleFactor = Float(min(1, RAWTuning.probeLongSide / longSide))
        guard let probe = filter.outputImage, let median = medianLuminance(of: probe), median > 0 else { return 0 }
        let ev = log2(RAWTuning.targetMedianLuminance / median)
        return min(max(ev, RAWTuning.minExposure), RAWTuning.maxExposure)
    }

    /// 선형 밝기의 중앙값 (밝은 창문 하나에 끌려가지 않게 평균 대신 중앙값)
    private static func medianLuminance(of image: CIImage) -> Double? {
        let extent = image.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        guard width > 0, height > 0, let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return nil }
        var pixels = [Float](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &pixels, rowBytes: width * 16, bounds: extent, format: .RGBAf, colorSpace: linear)
        var values = [Float]()
        values.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            values.append(0.2126 * pixels[index] + 0.7152 * pixels[index + 1] + 0.0722 * pixels[index + 2])
        }
        values.sort()
        return Double(values[values.count / 2])
    }
}

/// RAW 현상 고정 값 (IMG_7554 RAW를 디카 사진 IMG_0146에 맞춰 정함)
private enum RAWTuning {
    /// 현상 후 밝기 중앙값 목표 (선형). 서랍 사진에서 디카에 맞춘 값
    static let targetMedianLuminance = 0.25
    /// 자동 밝기 범위 (EV). 너무 어두운 곳에서 노이즈가 커지지 않게 위를 막음
    static let minExposure = -1.0
    static let maxExposure = 2.5
    /// 이보다 따뜻한 조명은 중립 쪽으로 당김 (K)
    static let neutralTemperature = 5000.0
    /// 차이의 몇 배만큼 당길지, 최대 얼마까지 (K)
    static let warmthRemoval = 0.9
    static let maxTemperatureShift = 800.0
    /// 밝기를 잴 때 쓰는 작은 현상본의 긴 변 (픽셀)
    static let probeLongSide: CGFloat = 256
    static let jpegQuality = 0.92
}
