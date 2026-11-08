//
//  PreviewBackdrop.swift
//  포징
//
//  미리보기 바깥(상단 바 · 하단 영역) 배경: 기본 카메라처럼 장면이 어둡게 비친다 (docs/02_UI.md 5절).
//  같은 세션에 두 번째 미리보기 층을 화면 전체에 붙이고, 어둡게 덮는 것은 OutsidePreviewDim이 한다.
//  층을 붙였다 떼면 세션이 다시 구성되어 앱이 멈추므로, 앱을 켤 때 한 번만 붙이고 보이기 · 숨기기만 한다.
//

import SwiftUI
@preconcurrency import AVFoundation

struct PreviewBackdrop: UIViewRepresentable {

    let source: PreviewSource

    func makeUIView(context: Context) -> BackdropView {
        let view = BackdropView()
        source.connect(to: view)
        return view
    }

    func updateUIView(_ view: BackdropView, context: Context) {}

    final class BackdropView: UIView, PreviewTarget {

        /// CaptureService가 메인 미리보기 층과 구분하는 이름
        nonisolated static let layerName = "posing.backdrop"

        init() {
            super.init(frame: .zero)
            backgroundColor = .black
            isUserInteractionEnabled = false
            previewLayer.name = Self.layerName
            previewLayer.videoGravity = .resizeAspectFill
            // 늦게 시작(deferred start)은 쓰지 않음: 세션 구성이 바뀐 뒤 이 층만 검정으로 남는 경우가 있어서
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
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        nonisolated func setSession(_ session: AVCaptureSession) {
            Task { @MainActor in
                previewLayer.session = session
            }
        }
    }
}

/// 미리보기 자리 바깥을 어둡게 덮음. 바깥에 비치는 장면(배경 층, 1:1일 때 4:3 영상의 위아래)이 반투명하게 보임
struct OutsidePreviewDim: View {

    let previewRect: CGRect

    var body: some View {
        Color.black
            .opacity(AppDefaults.outsidePreviewDimOpacity)
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
