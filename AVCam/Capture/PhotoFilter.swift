//
//  PhotoFilter.swift
//  포징
//
//  저장 직전 사진에 입히는 색 보정 (docs/05_TECH_NOTES.md 4절).
//  카메라 색감(.cube, 플래시 사진은 플래시 전용) → 스타일 → 디카 질감 순서.
//  원본 메타데이터는 그대로 옮기고, CaptureService 액터 안에서 부른다 (메인 스레드 밖).
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

enum PhotoFilter {

    private static let context = CIContext()

    /// 카메라 색감(LUT) → (플래시 사진이면 사람 밝게 · 배경 어둡게) → 스타일 → 디카 질감 순으로 입힘.
    /// 플래시가 터진 사진은 플래시 전용 색감을 씀. 실패하면 원본 데이터를 그대로 돌려줌 (사진을 잃지 않게)
    static func apply(look: PhotoLook?, style: StyleSelection?, to data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source)
        else { return data }
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let flashFired = didFlashFire(properties)
        let lutURL = flashFired ? (look?.flashLUTURL ?? look?.lutURL) : look?.lutURL
        let lut = lutURL.flatMap(CubeLUT.init(contentsOf:))
        let finish = look?.finish
        let usesFalloff = flashFired && finish?.hasFlashFalloff == true
        // 바꿀 것이 하나도 없으면 손대지 않음
        guard lut != nil || style?.changesImage == true || finish?.hasTexture == true || usesFalloff,
              let input = CIImage(data: data)
        else { return data }

        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        let mask = usesFalloff ? DigicamFinish.personMask(for: input, orientation: orientation, context: context) : nil
        let output = filtered(input, lut: lut, style: style, finish: finish, subjectMask: mask)
        // 원본과 같은 색공간으로 다시 씀 (기기 사진은 Display P3)
        guard let colorSpace = input.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let image = context.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: colorSpace)
        else { return data }

        properties[kCGImageDestinationLossyCompressionQuality] = 0.9
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, type, 1, nil) else { return data }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return result as Data
    }

    /// EXIF 플래시 값의 첫 비트 = 플래시가 터짐
    private static func didFlashFire(_ properties: [CFString: Any]) -> Bool {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        guard let flash = exif?[kCGImagePropertyExifFlash] as? Int else { return false }
        return flash & 1 == 1
    }

    /// 필터 체인. 미리보기(6단계)도 같은 함수를 쓴다 (미리보기는 사람 마스크 없음)
    static func filtered(_ image: CIImage, lut: CubeLUT?, style: StyleSelection?,
                         finish: CameraFinish? = nil, subjectMask: CIImage? = nil,
                         grainOffset: CGPoint = .zero) -> CIImage {
        var output = image
        if let lut, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) {
            let filter = CIFilter.colorCubeWithColorSpace()
            filter.inputImage = output
            filter.cubeDimension = Float(lut.size)
            filter.cubeData = lut.rgbaData
            filter.colorSpace = sRGB
            output = filter.outputImage ?? output
        }
        if let finish, let subjectMask {
            output = DigicamFinish.applyFlashFalloff(output, finish: finish, mask: subjectMask)
        }
        if let style, style.changesImage {
            output = StyleFilter.apply(style, to: output)
        }
        if let finish, finish.hasTexture {
            output = DigicamFinish.applyTexture(output, finish: finish, grainOffset: grainOffset)
        }
        return output.cropped(to: image.extent)
    }
}

/// `.cube` 3D LUT 텍스트를 읽은 값. 빨강이 가장 빨리 바뀌는 순서라 CIColorCube와 같음
struct CubeLUT {

    let size: Int
    let rgbaData: Data

    init?(contentsOf url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(text: text)
    }

    init?(text: String) {
        var size = 0
        var values: [Float] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard let first = parts.first, !first.hasPrefix("#") else { continue }
            switch first {
            case "LUT_3D_SIZE":
                guard parts.count == 2, let parsed = Int(parts[1]) else { return nil }
                size = parsed
            case "LUT_1D_SIZE":
                return nil
            case "DOMAIN_MIN":
                guard parts.dropFirst().allSatisfy({ Float($0) == 0 }) else { return nil }
            case "DOMAIN_MAX":
                guard parts.dropFirst().allSatisfy({ Float($0) == 1 }) else { return nil }
            default:
                // 숫자 3개가 아닌 줄(TITLE 등)은 건너뜀
                let rgb = parts.compactMap { Float($0) }
                guard parts.count == 3, rgb.count == 3 else { continue }
                values.append(contentsOf: rgb + [1])
            }
        }
        guard (2...128).contains(size), values.count == size * size * size * 4 else { return nil }
        self.size = size
        rgbaData = values.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
