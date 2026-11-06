//
//  StyleFilter.swift
//  포징
//
//  스타일 = 기본 룩(팔레트만큼 섞음) → 톤 → 색상 (docs/05_TECH_NOTES.md 4절).
//  숫자는 StylePresets.swift에 모아 둔다.
//

import CoreImage
import CoreImage.CIFilterBuiltins

enum StyleFilter {

    static func apply(_ selection: StyleSelection, to image: CIImage) -> CIImage {
        let preset = selection.style.preset
        let values = selection.values
        var output = image
        // 흑백은 팔레트와 상관없이 먼저 흑백으로
        if preset.look.isMono {
            output = colorControls(output, saturation: 0)
        }
        if preset.hasPalette {
            output = mix(output, with: look(preset.look, on: output), amount: values.palette / 100)
        }
        output = tone(output, amount: values.tone / 100)
        if preset.look.isMono {
            output = temperature(output, coolness: -values.color / 100 * StyleTuning.monoWarmth)
        } else {
            output = color(output, amount: values.color / 100)
        }
        return output
    }

    private static func look(_ look: StyleLook, on image: CIImage) -> CIImage {
        var output = colorControls(image, saturation: look.isMono ? 0 : look.saturation,
                                   contrast: look.contrast, brightness: look.brightness)
        if look.coolness != 0 {
            output = temperature(output, coolness: look.coolness)
        }
        return output
    }

    /// 마이너스 = 그림자 진하게 · 대비 강하게, 플러스 = 밝고 부드럽게
    private static func tone(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let shadow: Double
        let midtone: Double
        let highlight: Double
        if amount < 0 {
            shadow = 0.25 + amount * StyleTuning.deepShadow
            midtone = 0.5
            highlight = 0.75 - amount * StyleTuning.deepHighlight
        } else {
            shadow = 0.25 + amount * StyleTuning.liftShadow
            midtone = 0.5 + amount * StyleTuning.liftMidtone
            highlight = 0.75 + amount * StyleTuning.liftHighlight
        }
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: 0, y: 0)
        filter.point1 = CGPoint(x: 0.25, y: shadow)
        filter.point2 = CGPoint(x: 0.5, y: midtone)
        filter.point3 = CGPoint(x: 0.75, y: highlight)
        filter.point4 = CGPoint(x: 1, y: 1)
        return filter.outputImage ?? image
    }

    /// 채도 · 색 강도
    private static func color(_ image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        let saturated = colorControls(image, saturation: 1 + amount * StyleTuning.saturation)
        let filter = CIFilter.vibrance()
        filter.inputImage = saturated
        filter.amount = Float(amount * StyleTuning.vibrance)
        return filter.outputImage ?? saturated
    }

    private static func colorControls(_ image: CIImage, saturation: Double, contrast: Double = 1,
                                      brightness: Double = 0) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = Float(saturation)
        filter.contrast = Float(contrast)
        filter.brightness = Float(brightness)
        return filter.outputImage ?? image
    }

    /// 플러스 = 차갑게
    private static func temperature(_ image: CIImage, coolness: Double) -> CIImage {
        guard coolness != 0 else { return image }
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6500, y: 0)
        filter.targetNeutral = CIVector(x: 6500 + coolness, y: 0)
        return filter.outputImage ?? image
    }

    /// 원본과 룩을 amount(0~1)만큼 섞음
    private static func mix(_ image: CIImage, with target: CIImage, amount: Double) -> CIImage {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = image
        filter.targetImage = target
        filter.time = Float(min(max(amount, 0), 1))
        return filter.outputImage ?? image
    }
}
