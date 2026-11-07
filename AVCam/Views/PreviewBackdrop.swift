//
//  PreviewBackdrop.swift
//  포징
//
//  미리보기 바깥(상단 바 · 하단 영역) 배경: 기본 카메라처럼 장면을 화면 전체에 크게 흐리고 어둡게 깐다.
//  검정 위에서는 유리 버튼(모드 줄 · 전환 버튼 등)에 비칠 것이 없어 유리처럼 보이지 않기 때문.
//  같은 세션에 두 번째 미리보기 층을 붙이고(늦게 시작), 흐림 · 어둡게는 화면에서만 한다.
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
            // 메인 미리보기가 먼저 보이도록 이 층은 늦게 시작
            previewLayer.isDeferredStartEnabled = true
    #if targetEnvironment(simulator)
            // 시뮬레이터는 카메라가 없어 샘플 이미지
            let imageView = UIImageView(image: UIImage(named: "video_mode"))
            imageView.contentMode = .scaleAspectFill
            imageView.frame = bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
    #endif
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            blur.frame = bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
            let dim = UIView(frame: bounds)
            dim.backgroundColor = UIColor.black.withAlphaComponent(AppDefaults.backdropDimOpacity)
            dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(dim)
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
