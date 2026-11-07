//
//  FilteredPreviewRenderer.swift
//  포징
//
//  보정된 프레임을 Metal로 그리는 뷰 (docs/05_TECH_NOTES.md 4절).
//  기존 미리보기 층 위에 같은 크기 · 같은 채우기로 겹친다. 탭 초점 좌표는 아래 미리보기 층이 그대로 처리한다.
//  보정이 없으면 멈추고 숨긴다 (배터리 절약).
//

import CoreImage
import MetalKit

@MainActor
final class FilteredPreviewRenderer: NSObject, MTKViewDelegate {

    let view: MTKView
    private let feed: FilteredPreviewFeed
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

    init?(feed: FilteredPreviewFeed) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        self.feed = feed
        self.commandQueue = commandQueue
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        view = MTKView(frame: .zero, device: device)
        super.init()
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        (view.layer as? CAMetalLayer)?.colorspace = colorSpace
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = AppDefaults.filteredPreviewFrameRate
        view.isPaused = true
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.delegate = self
    }

    /// 보정을 켜면 그리기 시작 (첫 프레임을 그린 뒤 보임), 끄면 멈추고 숨김
    func setActive(_ isActive: Bool) {
        view.isPaused = !isActive
        if !isActive { view.isHidden = true }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let frame = feed.filteredFrame(),
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }
        let size = view.drawableSize
        guard size.width > 0, size.height > 0, !frame.extent.isEmpty else { return }

        // 미리보기 층과 같은 채우기 (resizeAspectFill): 가운데 기준으로 꽉 채움
        let extent = frame.extent
        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = frame
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offsetX = (size.width - extent.width * scale) / 2
        let offsetY = (size.height - extent.height * scale) / 2
        let image = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        let destination = CIRenderDestination(width: Int(size.width), height: Int(size.height),
                                              pixelFormat: view.colorPixelFormat, commandBuffer: commandBuffer) {
            drawable.texture
        }
        destination.colorSpace = colorSpace
        // Core Image는 아래가 원점, Metal 텍스처는 위가 원점
        destination.isFlipped = true
        do {
            try context.startTask(toRender: image, to: destination)
        } catch {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        if view.isHidden { view.isHidden = false }
    }
}
