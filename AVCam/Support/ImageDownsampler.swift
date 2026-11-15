//
//  ImageDownsampler.swift
//  포징
//
//  큰 사진을 원본 크기로 풀지 않고 필요한 크기로만 읽는다 (ImageIO 썸네일).
//

import ImageIO
import UIKit

enum ImageDownsampler {

    /// 목록 칸 썸네일 크기 (56pt × 3배)
    static let thumbnailPixels = 168

    static func image(at url: URL, maxPixels: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = cgImage(from: source, maxPixels: maxPixels)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 방향을 바로잡고 긴 변을 maxPixels 이하로 줄인 이미지
    static func cgImage(from source: CGImageSource, maxPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
