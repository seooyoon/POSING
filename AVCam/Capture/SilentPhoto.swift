//
//  SilentPhoto.swift
//  포징
//
//  무음 촬영 (설정 > 무음 촬영). 사진 출력은 한국 아이폰에서 찰칵 소리를 끌 수 없어서,
//  카메라 영상 프레임 한 장을 떼어 JPEG로 만든다. 화질은 사진 출력보다 낮고 플래시 · LIVE · RAW는 없음.
//

import CoreImage
import ImageIO

enum SilentPhoto {

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// 미리보기 방향으로 돌아 있는 프레임을 사진 방향으로 돌려 JPEG로.
    /// `rotation`: 더 돌릴 각도 (시계 방향, 90도 단위)
    static func jpegData(from frame: CIImage, rotation: CGFloat) -> Data? {
        let quarterTurns = (Int((rotation / 90).rounded()) % 4 + 4) % 4
        // Core Image는 아래가 원점이라 시계 방향 회전은 음의 각도
        let rotated = quarterTurns == 0 ? frame
            : frame.transformed(by: CGAffineTransform(rotationAngle: -CGFloat(quarterTurns) * .pi / 2))
        let image = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX,
                                                              y: -rotated.extent.minY))
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: AppDefaults.silentPhotoQuality]
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: options)
    }
}
