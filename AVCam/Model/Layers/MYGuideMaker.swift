//
//  MYGuideMaker.swift
//  포징
//
//  MY 사진에서 사람 외곽선 · 얼굴 점(눈 · 코 · 입)을 그린 투명 이미지를 만든다 (docs/01_SPEC.md 5절).
//  Vision으로 기기 안에서만 인식 (오프라인). 화면에만 겹치고 저장본에는 넣지 않는다.
//  메인 스레드 밖에서 부른다.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

enum MYGuideMaker {

    /// 가이드 이미지 긴 변 (화면 폭에 맞춰 늘려 보여도 선이 거칠지 않을 만큼)
    private static let longSide: CGFloat = 1200
    /// 외곽선 두께 (긴 변 비율)
    private static let lineRatio: CGFloat = 0.006
    /// 얼굴 점 반지름 (긴 변 비율)
    private static let dotRatio: CGFloat = 0.006
    /// 밝은 배경에서도 보이게 선 · 점 둘레에 까는 옅은 그림자 (긴 변 비율)
    private static let shadowRatio: CGFloat = 0.004

    private static let context = CIContext()

    /// 사람도 얼굴도 못 찾으면 nil
    static func guide(for image: UIImage) -> UIImage? {
        guard let cgImage = upright(image).cgImage else { return nil }
        let original = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(1, longSide / max(original.width, original.height))
        let size = CGSize(width: (original.width * scale).rounded(), height: (original.height * scale).rounded())

        let segmentation = VNGeneratePersonSegmentationRequest()
        segmentation.qualityLevel = .accurate
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let faces = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        // 인식 자체가 실패하면 가이드 없이 사진만
        do {
            try handler.perform([segmentation, faces])
        } catch {
            return nil
        }

        let outline = segmentation.results?.first.flatMap { outlineImage(mask: $0.pixelBuffer, size: size) }
        let points = (faces.results ?? []).flatMap { facePoints($0, size: size) }
        guard outline != nil || !points.isEmpty else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let radius = max(size.width, size.height) * dotRatio
        let shadow = max(size.width, size.height) * shadowRatio
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            // 그림자는 여기서 한 번만 그려 넣음 (화면에서 .shadow를 쓰면 매 프레임 다시 계산해 화면이 밀림)
            renderer.cgContext.setShadow(offset: .zero, blur: shadow, color: UIColor.black.withAlphaComponent(0.6).cgColor)
            if let outline {
                UIImage(cgImage: outline).draw(in: CGRect(origin: .zero, size: size))
            }
            UIColor.white.setFill()
            for point in points {
                renderer.cgContext.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                                          width: radius * 2, height: radius * 2))
            }
        }
    }

    /// 방향 정보가 있는 사진은 똑바로 다시 그려 픽셀과 화면 방향을 맞춤 (Vision은 .up으로 분석)
    private static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 사람 영역 가장자리만 흰 선으로 (나머지는 투명)
    private static func outlineImage(mask buffer: CVPixelBuffer, size: CGSize) -> CGImage? {
        var mask = CIImage(cvPixelBuffer: buffer)
        mask = mask.transformed(by: CGAffineTransform(scaleX: size.width / mask.extent.width,
                                                       y: size.height / mask.extent.height))
        let rect = CGRect(origin: .zero, size: size)
        let lineWidth = max(size.width, size.height) * lineRatio
        // 계단 무늬가 보이지 않게 살짝 흐린 뒤 반으로 나눠 또렷한 경계로
        let smooth = mask.clampedToExtent().applyingGaussianBlur(sigma: lineWidth).cropped(to: rect)
        let threshold = CIFilter.colorThreshold()
        threshold.inputImage = smooth
        threshold.threshold = 0.5
        // 경계 안팎으로 두께만큼 = 선. 사진 테두리에 닿은 곳은 선이 생기지 않게 바깥을 늘려 둠
        let edge = CIFilter.morphologyGradient()
        edge.inputImage = threshold.outputImage?.clampedToExtent()
        edge.radius = Float(lineWidth / 2)
        guard let edgeMask = edge.outputImage?.cropped(to: rect) else { return nil }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = CIImage(color: .white).cropped(to: rect)
        blend.backgroundImage = CIImage(color: .clear).cropped(to: rect)
        blend.maskImage = edgeMask
        guard let output = blend.outputImage else { return nil }
        return context.createCGImage(output, from: rect)
    }

    /// 얼굴마다 왼눈 · 오른눈 · 코 · 입 가운데 (위가 0인 이미지 좌표)
    private static func facePoints(_ face: VNFaceObservation, size: CGSize) -> [CGPoint] {
        guard let landmarks = face.landmarks else { return [] }
        let regions = [landmarks.leftPupil ?? landmarks.leftEye,
                       landmarks.rightPupil ?? landmarks.rightEye,
                       landmarks.nose,
                       landmarks.outerLips]
        return regions.compactMap { region in
            guard let points = region?.pointsInImage(imageSize: size), !points.isEmpty else { return nil }
            let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
            // Vision은 아래가 0
            return CGPoint(x: x, y: size.height - y)
        }
    }
}
