//
//  PhotoFilter.swift
//  포징
//
//  저장 직전 사진에 입히는 색 보정 (docs/05_TECH_NOTES.md 4절).
//  카메라 색감(.cube) → 스타일 순서.
//  원본 메타데이터는 그대로 옮기고, CaptureService 액터 안에서 부른다 (메인 스레드 밖).
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

enum PhotoFilter {

    private static let context = CIContext()

    /// 카메라 색감(LUT) → 스타일 순으로 입힘. 실패하면 원본 데이터를 그대로 돌려줌 (사진을 잃지 않게)
    static func apply(lut lutURL: URL?, style: StyleSelection?, to data: Data) -> Data {
        let lut = lutURL.flatMap(CubeLUT.init(contentsOf:))
        // LUT를 못 읽었고 스타일도 보정 없음이면 손대지 않음
        guard lut != nil || style?.changesImage == true,
              let input = CIImage(data: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source)
        else { return data }

        let output = filtered(input, lut: lut, style: style)
        // 원본과 같은 색공간으로 다시 씀 (기기 사진은 Display P3)
        guard let colorSpace = input.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let image = context.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: colorSpace)
        else { return data }

        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        properties[kCGImageDestinationLossyCompressionQuality] = 0.9
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, type, 1, nil) else { return data }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return result as Data
    }

    /// 필터 체인. 미리보기(6단계)도 같은 함수를 쓴다
    static func filtered(_ image: CIImage, lut: CubeLUT?, style: StyleSelection?) -> CIImage {
        var output = image
        if let lut, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) {
            let filter = CIFilter.colorCubeWithColorSpace()
            filter.inputImage = output
            filter.cubeDimension = Float(lut.size)
            filter.cubeData = lut.rgbaData
            filter.colorSpace = sRGB
            output = filter.outputImage ?? output
        }
        if let style, style.changesImage {
            output = StyleFilter.apply(style, to: output)
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
