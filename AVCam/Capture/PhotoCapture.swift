/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a photo capture output to take photographs.
*/

import AVFoundation
import CoreImage

enum PhotoCaptureError: Error {
    case noPhotoData
}

/// An object that manages a photo capture output to perform take photographs.
final class PhotoCapture: OutputService {
    
    /// A value that indicates the current state of photo capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service.
    let output = AVCapturePhotoOutput()
    
    // An internal alias for the output.
    private var photoOutput: AVCapturePhotoOutput { output }
    
    // The current capabilities available.
    private(set) var capabilities: CaptureCapabilities = .unknown
    
    /// RAW(Apple ProRAW) 촬영 준비. 켜면 세션 구성이 다시 일어나므로 RAW를 고를 때만 켬
    var isRAWEnabled = false {
        didSet { applyRAWEnabled() }
    }

    private func applyRAWEnabled() {
        guard photoOutput.isAppleProRAWSupported else { return }
        photoOutput.isAppleProRAWEnabled = isRAWEnabled
    }

    // A count of Live Photo captures currently in progress.
    private var livePhotoCount = 0
    
    // MARK: - Capture a photo.
    
    /// The app calls this method when the user taps the photo capture button.
    /// `onCaptured`: 센서가 찍기를 마친 순간 (플래시 포함). 이때부터 다음 셔터를 받음
    func capturePhoto(with features: PhotoFeatures, onCaptured: @escaping @Sendable () -> Void) async throws -> Photo {
        // Wrap the delegate-based capture API in a continuation to use it in an async context.
        try await withCheckedThrowingContinuation { continuation in
            
            // Create a settings object to configure the photo capture.
            let photoSettings = createPhotoSettings(with: features)
            
            let delegate = PhotoCaptureDelegate(continuation: continuation, onCaptured: onCaptured)
            monitorProgress(of: delegate)
            
            // Capture a new photo with the specified settings.
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    // MARK: - Create a photo settings object.
    
    // Create a photo settings object with the features a person enables in the UI.
    private func createPhotoSettings(with features: PhotoFeatures) -> AVCapturePhotoSettings {
        // Create a new settings object to configure the photo capture.
        var photoSettings = AVCapturePhotoSettings()
        
        // 형식 버튼에서 고른 RAW / JPEG (지원하지 않으면 기본값)
        let rawFormat = features.isRAW ? photoOutput.availableRawPhotoPixelFormatTypes.first {
            AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
        } : nil
        if let rawFormat {
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
            // 사진 앱 저장 전 썸네일을 빨리 만들 수 있게 작은 그림을 넣음
            if let thumbnailCodec = photoSettings.availableRawEmbeddedThumbnailPhotoCodecTypes.first {
                photoSettings.rawEmbeddedThumbnailPhotoFormat = [AVVideoCodecKey: thumbnailCodec]
            }
        } else if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        }
        
        /// Set the format of the preview image to capture. The `photoSettings` object returns the available
        /// preview format types in order of compatibility with the primary image.
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        
        /// Set the largest dimensions that the photo output supports.
        /// `CaptureService` automatically updates the photo output's `maxPhotoDimensions`
        /// when the capture pipeline changes.
        photoSettings.maxPhotoDimensions = features.maxDimensions ?? photoOutput.maxPhotoDimensions
        
        // Set the movie URL if the photo output supports Live Photo capture.
        // ProRAW는 LIVE와 함께 쓸 수 없음
        photoSettings.livePhotoMovieFileURL = features.isLivePhotoEnabled && rawFormat == nil ? URL.movieFileURL : nil
        
        // 플래시 (출력이 지원하는 값만)
        if photoOutput.supportedFlashModes.contains(features.flashMode) {
            photoSettings.flashMode = features.flashMode
        }
        
        // Set the priority of speed versus quality during this capture.
        if let prioritization = AVCapturePhotoOutput.QualityPrioritization(rawValue: features.qualityPrioritization.rawValue) {
            photoSettings.photoQualityPrioritization = prioritization
        }
        
        return photoSettings
    }
    
    /// Monitors the progress of a photo capture delegate.
    ///
    /// The `PhotoCaptureDelegate` produces an asynchronous stream of values that indicate its current activity.
    /// The app propagates the activity values up to the view tier so the UI can update accordingly.
    private func monitorProgress(of delegate: PhotoCaptureDelegate, isolation: isolated (any Actor)? = #isolation) {
        Task {
            _ = isolation
            var isLivePhoto = false
            // Asynchronously monitor the activity of the delegate while the system performs capture.
            for await activity in delegate.activityStream {
                var currentActivity = activity
                /// More than one activity value for the delegate may report that `isLivePhoto` is `true`.
                /// Only increment/decrement the count when the value changes from its previous state.
                if activity.isLivePhoto != isLivePhoto {
                    isLivePhoto = activity.isLivePhoto
                    // Increment or decrement as appropriate.
                    livePhotoCount += isLivePhoto ? 1 : -1
                    if livePhotoCount > 1 {
                        /// Set `isLivePhoto` to `true` when there are concurrent Live Photos in progress.
                        /// This prevents the "Live" badge in the UI from flickering.
                        currentActivity = .photoCapture(willCapture: activity.willCapture, isLivePhoto: true)
                    }
                }
                captureActivity = currentActivity
            }
        }
    }
    
    // MARK: - Update the photo output configuration
    
    /// Reconfigures the photo output and updates the output service's capabilities accordingly.
    ///
    /// The `CaptureService` calls this method whenever you change cameras.
    ///
    func updateConfiguration(for device: AVCaptureDevice) {
        // Enable all supported features.
        // 목록 순서는 보장되지 않으므로 픽셀 면적이 가장 큰 크기를 출력 최대로
        photoOutput.maxPhotoDimensions = Self.sortedByArea(device.activeFormat.supportedMaxPhotoDimensions).last ?? .zero
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        photoOutput.maxPhotoQualityPrioritization = .quality
        photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
        photoOutput.isFastCapturePrioritizationEnabled = photoOutput.isFastCapturePrioritizationSupported
        // 지연 처리는 항상 끔: 처리 전 사진은 자를 수 없고, 비율마다 켜고 끄면 세션이 다시 구성되어 미리보기가 흔들림
        photoOutput.isAutoDeferredPhotoDeliveryEnabled = false
        applyRAWEnabled()
        updateCapabilities(for: device)
    }
    
    private func updateCapabilities(for device: AVCaptureDevice) {
        capabilities = CaptureCapabilities(isLivePhotoCaptureSupported: photoOutput.isLivePhotoCaptureSupported,
                                           isFlashSupported: photoOutput.supportedFlashModes.contains(.on),
                                           photoDimensions: Self.photoDimensions(for: device),
                                           isRAWSupported: photoOutput.isAppleProRAWSupported)
    }

    /// 고를 수 있는 사진 크기. 트리플 카메라는 24MP까지만 주므로, 메인 렌즈가 더 큰 크기(48MP)를 지원하면
    /// 그 크기도 넣음 (그 해상도를 고르면 CameraModel이 메인 렌즈로 바꿈)
    private static func photoDimensions(for device: AVCaptureDevice) -> [CMVideoDimensions] {
        var dimensions = sortedByArea(device.activeFormat.supportedMaxPhotoDimensions)
        guard device.isVirtualDevice,
              let main = device.constituentDevices.first(where: { $0.deviceType == .builtInWideAngleCamera }),
              let largest = sortedByArea(main.formats.flatMap(\.supportedMaxPhotoDimensions)).last else {
            return dimensions
        }
        if area(largest) > dimensions.last.map(area) ?? 0 {
            dimensions.append(largest)
        }
        return dimensions
    }

    private static func sortedByArea(_ dimensions: [CMVideoDimensions]) -> [CMVideoDimensions] {
        dimensions.sorted { area($0) < area($1) }
    }

    private static func area(_ dimensions: CMVideoDimensions) -> Int {
        Int(dimensions.width) * Int(dimensions.height)
    }
}

extension AVCaptureDevice.FlashMode {
    init(_ mode: FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        }
    }
}

typealias PhotoContinuation = CheckedContinuation<Photo, Error>

// MARK: - A photo capture delegate to process the captured photo.

/// An object that adopts the `AVCapturePhotoCaptureDelegate` protocol to respond to photo capture life-cycle events.
///
/// The delegate produces a stream of events that indicate its current state of processing.
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    private let onCaptured: @Sendable () -> Void
    
    private var isLivePhoto = false
    private var isProxyPhoto = false
    
    private var photoData: Data?
    private var livePhotoMovieURL: URL?
    
    /// A stream of capture activity values that indicate the current state of progress.
    let activityStream: AsyncStream<CaptureActivity>
    private let activityContinuation: AsyncStream<CaptureActivity>.Continuation
    
    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(continuation: PhotoContinuation, onCaptured: @escaping @Sendable () -> Void) {
        self.continuation = continuation
        self.onCaptured = onCaptured
        
        let (activityStream, activityContinuation) = AsyncStream.makeStream(of: CaptureActivity.self)
        self.activityStream = activityStream
        self.activityContinuation = activityContinuation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Determine if this is a live capture.
        isLivePhoto = resolvedSettings.livePhotoMovieDimensions != .zero
        activityContinuation.yield(.photoCapture(isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Signal that a capture is beginning.
        activityContinuation.yield(.photoCapture(willCapture: true, isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        onCaptured()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Indicates that Live Photo capture is over.
        activityContinuation.yield(.photoCapture(isLivePhoto: false))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            logger.debug("Error processing Live Photo companion movie: \(String(describing: error))")
        }
        livePhotoMovieURL = outputFileURL
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
        if let error = error {
            logger.debug("Error capturing deferred photo: \(error)")
            return
        }
        // Capture the data for this photo.
        photoData = deferredPhotoProxy?.fileDataRepresentation()
        isProxyPhoto = true
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.notice("[Photo] processing error: \(String(describing: error), privacy: .public)")
            return
        }
        photoData = photo.fileDataRepresentation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {

        defer {
            /// Finish the continuation to terminate the activity stream.
            activityContinuation.finish()
        }

        // If an error occurs, resume the continuation by throwing an error, and return.
        if let error {
            continuation.resume(throwing: error)
            return
        }
        
        // If the app captures no photo data, resume the continuation by throwing an error, and return.
        guard let photoData else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }
        
        /// Create a photo object to save to the `MediaLibrary`.
        let photo = Photo(data: photoData, isProxy: isProxyPhoto, livePhotoMovieURL: livePhotoMovieURL)
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}
