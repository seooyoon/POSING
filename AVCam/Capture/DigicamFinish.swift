//
//  DigicamFinish.swift
//  포징
//
//  디카 느낌 후처리 (docs/05_TECH_NOTES.md 4-2절).
//  플래시 사진은 사람을 밝게 · 배경을 어둡게, 모든 사진은 살짝 부드럽게 + 고운 노이즈 + 가장자리 어둡게.
//  카메라마다 `camera_XX_이름.json`에 값을 두고, 파일이 없으면 아무것도 하지 않는다. 모두 기기 안에서 처리 (오프라인).
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import Vision

enum DigicamFinish {

    // MARK: - 플래시: 사람 밝게 · 배경 어둡게

    /// 마스크(1 = 사람) 안은 사람 밝기, 밖은 배경 밝기로
    static func applyFlashFalloff(_ image: CIImage, finish: CameraFinish, mask: CIImage) -> CIImage {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = exposure(image, ev: finish.flashSubjectEV)
        blend.backgroundImage = exposure(image, ev: finish.flashBackgroundEV)
        blend.maskImage = mask
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }

    /// 사진 속 사람 영역 (1 = 사람, 경계는 부드럽게). 사람이 거의 없거나 실패하면 nil
    /// `image`는 방향을 적용하지 않은 원본 픽셀, `orientation`은 사진의 방향 값
    static func personMask(for image: CIImage, orientation: CGImagePropertyOrientation, context: CIContext) -> CIImage? {
        // 똑바로 세운 작은 이미지로 인식 (빠르고, 사람 인식이 정확함)
        var upright = image.oriented(orientation)
        upright = upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX, y: -upright.extent.minY))
        let uprightSize = upright.extent.size
        let scale = min(1, FinishTuning.maskLongSide / max(uprightSize.width, uprightSize.height))
        let small = upright.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(ciImage: small, options: [.ciContext: context])
        guard (try? handler.perform([request])) != nil,
              let buffer = request.results?.first?.pixelBuffer else { return nil }

        var mask = CIImage(cvPixelBuffer: buffer)
        guard coverage(of: mask, context: context) >= FinishTuning.minPersonCoverage else { return nil }
        // 세운 크기 → 원래 방향 → 원본 픽셀 자리로
        mask = mask.transformed(by: CGAffineTransform(scaleX: uprightSize.width / mask.extent.width,
                                                       y: uprightSize.height / mask.extent.height))
        mask = mask.oriented(inverse(of: orientation))
        mask = mask.transformed(by: CGAffineTransform(translationX: image.extent.minX - mask.extent.minX,
                                                       y: image.extent.minY - mask.extent.minY))
        let feather = min(image.extent.width, image.extent.height) * FinishTuning.maskFeather
        return mask.clampedToExtent().applyingGaussianBlur(sigma: feather).cropped(to: image.extent)
    }

    // MARK: - 질감: 부드럽게 · 노이즈 · 가장자리 어둡게

    /// `grainOffset`: 미리보기에서 프레임마다 노이즈 위치를 바꿔 화면에 무늬가 박혀 보이지 않게
    static func applyTexture(_ image: CIImage, finish: CameraFinish, grainOffset: CGPoint = .zero) -> CIImage {
        let extent = image.extent
        let unit = min(extent.width, extent.height) / 1000
        var output = image
        if finish.softness > 0 {
            output = output.clampedToExtent().applyingGaussianBlur(sigma: finish.softness * unit).cropped(to: extent)
        }
        if finish.grain > 0 {
            output = addGrain(output, amount: finish.grain, size: max(1, unit * FinishTuning.grainSize), offset: grainOffset)
        }
        if finish.vignette > 0 {
            let vignette = CIFilter.vignetteEffect()
            vignette.inputImage = output
            vignette.center = CGPoint(x: extent.midX, y: extent.midY)
            vignette.radius = Float(hypot(extent.width, extent.height) / 2 * FinishTuning.vignetteRadius)
            vignette.intensity = Float(finish.vignette)
            vignette.falloff = Float(FinishTuning.vignetteFalloff)
            output = vignette.outputImage ?? output
        }
        return output.cropped(to: extent)
    }

    // MARK: - 내부

    private static func exposure(_ image: CIImage, ev: Double) -> CIImage {
        guard ev != 0 else { return image }
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(ev)
        return filter.outputImage ?? image
    }

    /// 흑백 노이즈를 눈에 보이는 밝기(sRGB) 기준으로 더함: 어두운 곳만 지저분해지지 않게
    private static func addGrain(_ image: CIImage, amount: Double, size: CGFloat, offset: CGPoint) -> CIImage {
        guard let noise = CIFilter.randomGenerator().outputImage else { return image }
        let gain = CGFloat(amount)
        let mono = noise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: -gain / 2, y: -gain / 2, z: -gain / 2, w: 0),
        ])
        .transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: size, y: size))
        let perceptual = image.applyingFilter("CILinearToSRGBToneCurve")
        let grained = mono.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: perceptual])
        return grained.applyingFilter("CISRGBToneCurveToLinear").cropped(to: image.extent)
    }

    /// 마스크 평균 밝기 = 사진에서 사람이 차지하는 비율
    private static func coverage(of mask: CIImage, context: CIContext) -> Double {
        let average = CIFilter.areaAverage()
        average.inputImage = mask
        average.extent = mask.extent
        guard let output = average.outputImage else { return 0 }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return Double(pixel[0]) / 255
    }

    /// 방향을 되돌리는 값: 왼쪽 · 오른쪽 90도만 서로 바뀌고 나머지는 자기 자신
    private static func inverse(of orientation: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .left: .right
        case .right: .left
        default: orientation
        }
    }
}

/// 질감 · 사람 인식의 고정 값 (카메라마다 바꿀 값은 json에)
private enum FinishTuning {
    /// 사람 인식에 쓰는 이미지의 긴 변 (픽셀)
    static let maskLongSide: CGFloat = 1024
    /// 사람이 이 비율보다 작으면 사람 없음으로 봄
    static let minPersonCoverage = 0.03
    /// 사람 경계를 부드럽게 (짧은 변 대비)
    static let maskFeather: CGFloat = 0.006
    /// 노이즈 알갱이 크기 (짧은 변 1000픽셀 기준)
    static let grainSize: CGFloat = 1.2
    /// 가장자리 어둡게가 시작되는 거리 (대각선 절반 대비)
    static let vignetteRadius = 0.7
    static let vignetteFalloff = 0.6
}
