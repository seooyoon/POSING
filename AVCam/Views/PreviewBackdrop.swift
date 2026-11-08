//
//  PreviewBackdrop.swift
//  포징
//
//  미리보기 바깥(상단 바 · 하단 영역) 배경: 기본 카메라처럼 더 넓은 초광각 화면이 어둡게 비친다 (docs/02_UI.md 5절).
//  초광각 프레임(UltraWideFeed)을 AVSampleBufferDisplayLayer로 그리고, 크기 · 위치는 CameraView가
//  미리보기와 같은 배율 · 중심으로 맞춰 하나로 이어지게 한다.
//  어둡게 덮거나 검정으로 가리는 것은 OutsidePreviewDim이 한다.
//

import SwiftUI
import AVFoundation

struct PreviewBackdrop: UIViewRepresentable {

    let source: PreviewSource
    /// 바깥이 비쳐 배경이 실제로 보이는지. 안 보이면 프레임을 받지 않음 (발열 줄이기)
    let isVisible: Bool

    func makeUIView(context: Context) -> BackdropView {
        let view = BackdropView()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: BackdropView, context: Context) {
        source.ultraWideFeed.setBackdrop(isVisible ? view.displayLayer.sampleBufferRenderer : nil)
    }

    /// 뷰가 사라질 때 연결을 끊으려고 프레임 출력을 들고 있음
    func makeCoordinator() -> UltraWideFeed { source.ultraWideFeed }

    static func dismantleUIView(_ view: BackdropView, coordinator: UltraWideFeed) {
        coordinator.setBackdrop(nil)
        view.displayLayer.sampleBufferRenderer.flush()
    }

    final class BackdropView: UIView {

        init() {
            super.init(frame: .zero)
            backgroundColor = .black
            isUserInteractionEnabled = false
            displayLayer.videoGravity = .resizeAspectFill
    #if targetEnvironment(simulator)
            // 시뮬레이터는 카메라가 없어 샘플 이미지
            let imageView = UIImageView(image: UIImage(named: "video_mode"))
            imageView.contentMode = .scaleAspectFill
            imageView.frame = bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
    #endif
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override class var layerClass: AnyClass {
            AVSampleBufferDisplayLayer.self
        }

        var displayLayer: AVSampleBufferDisplayLayer {
            layer as! AVSampleBufferDisplayLayer
        }
    }
}

/// 미리보기 자리 바깥을 어둡게 덮음. 바깥에 비치는 장면(배경 층, 1:1일 때 4:3 영상의 위아래)이 반투명하게 보임
/// 비치지 않을 때(isSeeThrough = false)는 바깥 전체가 같이 검정 (기본 카메라와 같은 규칙)
struct OutsidePreviewDim: View {

    let previewRect: CGRect
    let isSeeThrough: Bool

    var body: some View {
        Color.black
            .opacity(isSeeThrough ? AppDefaults.outsidePreviewDimOpacity : 1)
            .mask {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                    // 미리보기 자리만 뚫음 (비율을 바꿀 때 자리와 같이 움직임)
                    Rectangle()
                        .frame(width: previewRect.width, height: previewRect.height)
                        .offset(x: previewRect.minX, y: previewRect.minY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}
