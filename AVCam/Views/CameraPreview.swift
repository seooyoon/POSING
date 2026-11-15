/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents a video preview of the captured content.
*/

import SwiftUI
@preconcurrency import AVFoundation

struct CameraPreview: UIViewRepresentable {
    
    private let source: PreviewSource
    
    init(source: PreviewSource) {
        self.source = source
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let preview = PreviewView()
        // Connect the preview layer to the capture session.
        source.connect(to: preview)
        // 보정 미리보기는 미리보기 층 위에 겹침
        preview.attach(source.filteredFeed)
        return preview
    }
    
    func updateUIView(_ previewView: PreviewView, context: Context) {
        // No-op.
    }
    
    /// A class that presents the captured content.
    ///
    /// This class owns the `AVCaptureVideoPreviewLayer` that presents the captured content.
    ///
    class PreviewView: UIView, PreviewTarget {

        private var filteredRenderer: FilteredPreviewRenderer?

        init() {
            super.init(frame: .zero)
            // 16:9 · 1:1 사진은 4:3 영상을 가운데 기준으로 채워 보여줌 (저장본 자르기와 같은 범위)
            previewLayer.videoGravity = .resizeAspectFill
            // 렌즈 · 형식을 바꾸는 순간 영상 비율이 잠깐 달라져도 4:3 칸 밖으로 삐져나오지 않게 자름
            clipsToBounds = true
    #if targetEnvironment(simulator)
            // The capture APIs require running on a real device. If running
            // in Simulator, display a static image to represent the video feed.
            let imageView = UIImageView()
            imageView.image = UIImage(named: "video_mode")
            imageView.contentMode = .scaleAspectFill
            // The image view resizes to fill the preview area.
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
    #endif
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // Use the preview layer as the view's backing layer.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        /// 보정된 미리보기를 위에 겹침. 보정을 켜고 끌 때 그리기도 켜고 끔
        func attach(_ feed: FilteredPreviewFeed) {
            guard let renderer = FilteredPreviewRenderer(feed: feed) else { return }
            renderer.view.frame = bounds
            addSubview(renderer.view)
            filteredRenderer = renderer
    #if targetEnvironment(simulator)
            // 시뮬레이터는 샘플 이미지에 보정을 입혀 보여줌
            feed.setStaticImage(UIImage(named: "video_mode"))
    #endif
            feed.onChange = { [weak renderer] isFiltering in
                renderer?.setActive(isFiltering)
            }
            renderer.setActive(feed.isFiltering)
        }

        nonisolated func setSession(_ session: AVCaptureSession) {
            // Connects the session with the preview layer, which allows the layer
            // to provide a live view of the captured content.
            Task { @MainActor in
                previewLayer.session = session
            }
        }
    }
}

/// A protocol that enables a preview source to connect to a preview target.
///
/// The app provides an instance of this type to the client tier so it can connect
/// the capture session to the `PreviewView` view. It uses these protocols
/// to prevent explicitly exposing the capture objects to the UI layer.
///
protocol PreviewSource: Sendable {
    // Connects a preview destination to this source.
    func connect(to target: PreviewTarget)
    /// 보정 미리보기 프레임
    var filteredFeed: FilteredPreviewFeed { get }
}

/// A protocol that passes the app's capture session to the `CameraPreview` view.
protocol PreviewTarget {
    // Sets the capture session on the destination.
    func setSession(_ session: AVCaptureSession)
}

/// The app's default `PreviewSource` implementation.
struct DefaultPreviewSource: PreviewSource {
    
    private let session: AVCaptureSession
    let filteredFeed: FilteredPreviewFeed

    init(session: AVCaptureSession, filteredFeed: FilteredPreviewFeed) {
        self.session = session
        self.filteredFeed = filteredFeed
    }
    
    func connect(to target: PreviewTarget) {
        target.setSession(session)
    }
}
