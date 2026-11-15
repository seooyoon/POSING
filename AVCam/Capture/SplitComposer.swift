//
//  SplitComposer.swift
//  포징
//
//  분할 사진 합치기 (docs/05_TECH_NOTES.md 5-1절).
//  칸마다 사진 가운데를 칸 비율로 잘라 줄 없이 붙인다. 전체 비율은 찍을 때 고른 사진 비율.
//  기기 안에서만 처리 (오프라인), 메인 스레드 밖에서 부른다.
//

import CoreImage
import Foundation
import ImageIO

enum SplitComposer {

    private static let context = CIContext()

    /// 칸 사진들(순서대로) → 합친 JPEG. `heightRatio`는 세로 사진 기준 높이 / 폭
    static func compose(_ shots: [Data], layout: SplitLayout, heightRatio: CGFloat) -> Data? {
        let images = shots.compactMap { CIImage(data: $0, options: [.applyOrientationProperty: true]) }
        guard images.count == layout.count, let first = images.first else { return nil }
        // 첫 사진의 폭을 전체 폭으로 (칸이 원본보다 커지지 않게)
        let width = first.extent.width.rounded()
        let canvas = CGSize(width: width, height: (width * heightRatio).rounded())

        var output = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: canvas))
        for (index, image) in images.enumerated() {
            // 칸 자리는 위에서부터 재므로 Core Image(아래에서부터) 좌표로 뒤집음
            let top = layout.cellRect(index, in: canvas)
            let cell = CGRect(x: top.minX.rounded(), y: (canvas.height - top.maxY).rounded(),
                              width: top.width.rounded(), height: top.height.rounded())
            output = fill(image, into: cell).composited(over: output)
        }

        guard let colorSpace = first.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        return context.jpegRepresentation(of: output.cropped(to: CGRect(origin: .zero, size: canvas)),
                                          colorSpace: colorSpace,
                                          options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: AppDefaults.splitJPEGQuality])
    }

    /// 칸별 원본: 사진 가운데를 그 칸 비율로 잘라 원래 해상도 그대로 (합친 사진의 그 칸과 같은 영역)
    static func cropToCell(_ data: Data, index: Int, layout: SplitLayout, heightRatio: CGFloat) -> Data? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return nil }
        let cell = layout.cellRect(index, in: CGSize(width: 1, height: heightRatio))
        guard cell.width > 0, cell.height > 0 else { return nil }
        let extent = image.extent
        let cellAspect = cell.width / cell.height
        let size = cellAspect > extent.width / extent.height
            ? CGSize(width: extent.width, height: (extent.width / cellAspect).rounded())
            : CGSize(width: (extent.height * cellAspect).rounded(), height: extent.height)
        let rect = CGRect(x: (extent.midX - size.width / 2).rounded(), y: (extent.midY - size.height / 2).rounded(),
                          width: size.width, height: size.height)
        // 방향은 이미 적용했으므로 메타데이터의 방향은 '그대로'로 (촬영 정보 · 위치는 유지)
        var properties = image.properties
        properties[kCGImagePropertyOrientation as String] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        let cropped = image.cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .settingProperties(properties)
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        return context.jpegRepresentation(of: cropped, colorSpace: colorSpace,
                                          options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: AppDefaults.splitJPEGQuality])
    }

    /// 사진을 칸에 꽉 차게 키우고 가운데만 남김
    private static func fill(_ image: CIImage, into cell: CGRect) -> CIImage {
        let extent = image.extent
        let scale = max(cell.width / extent.width, cell.height / extent.height)
        let scaled = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let size = scaled.extent.size
        return scaled
            .transformed(by: CGAffineTransform(translationX: cell.midX - size.width / 2, y: cell.midY - size.height / 2))
            .cropped(to: cell)
    }
}
