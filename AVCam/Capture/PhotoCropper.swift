//
//  PhotoCropper.swift
//  포징
//
//  16:9 · 1:1 사진: 4:3 원본을 가운데 기준으로 잘라 같은 형식(HEIF/JPEG)으로 다시 쓴다 (docs/05_TECH_NOTES.md 5절).
//  원본 메타데이터(EXIF · GPS · 방향)는 그대로 옮긴다. 가운데 기준이라 방향(orientation)과 상관없이 같은 결과.
//  CaptureService 액터 안에서 부른다 (메인 스레드 밖).
//

import Foundation
import ImageIO

enum PhotoCropper {

    /// 실패하면 원본 데이터를 그대로 돌려줌 (사진을 잃지 않게)
    static func crop(_ data: Data, longToShort ratio: CGFloat) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return data }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let long = max(width, height)
        let short = min(width, height)
        // 16:9는 짧은 변을 줄이고, 1:1은 긴 변을 줄임
        var cropLong = long
        var cropShort = short
        if long / short < ratio {
            cropShort = (long / ratio).rounded(.down)
        } else {
            cropLong = (short * ratio).rounded(.down)
        }
        let cropWidth = width >= height ? cropLong : cropShort
        let cropHeight = width >= height ? cropShort : cropLong
        let rect = CGRect(x: ((width - cropWidth) / 2).rounded(.down),
                          y: ((height - cropHeight) / 2).rounded(.down),
                          width: cropWidth, height: cropHeight)
        guard let cropped = image.cropping(to: rect) else { return data }

        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        properties[kCGImagePropertyPixelWidth] = cropped.width
        properties[kCGImagePropertyPixelHeight] = cropped.height
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = cropped.width
            exif[kCGImagePropertyExifPixelYDimension] = cropped.height
            properties[kCGImagePropertyExifDictionary] = exif
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 0.9

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return data }
        CGImageDestinationAddImage(destination, cropped, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }
}
