//
//  PreviewBackdrop.swift
//  포징
//
//  미리보기 바깥(상단 바 · 하단 영역) 배경: 기본 카메라처럼 장면이 어둡게 비친다 (docs/02_UI.md 5절).
//  두 번째 미리보기 층(AVCaptureVideoPreviewLayer)은 같은 세션에서 영상이 나오지 않아,
//  프레임 출력(FilteredPreviewFeed)의 프레임을 AVSampleBufferDisplayLayer로 화면 전체에 그린다.
//  어둡게 덮거나 검정으로 가리는 것은 OutsidePreviewDim이 한다.
//

import SwiftUI
import AVFoundation

struct PreviewBackdrop: UIViewRepresentable {

    let source: PreviewSource

    func makeUIView(context: Context) -> BackdropView {
        let view = BackdropView()
        source.filteredFeed.setBackdrop(view.displayLayer.sampleBufferRenderer)
        return view
    }

    func updateUIView(_ view: BackdropView, context: Context) {}

    static func dismantleUIView(_ view: BackdropView, coordinator: ()) {
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
