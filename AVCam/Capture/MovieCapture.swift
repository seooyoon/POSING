/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a movie capture output to record videos.
*/

import AVFoundation
import Combine

/// An object that manages a movie capture output to record videos.
final class MovieCapture: OutputService {
    
    /// A value that indicates the current state of movie capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service.
    let output = AVCaptureMovieFileOutput()
    // An internal alias for the output.
    private var movieOutput: AVCaptureMovieFileOutput { output }
    
    // A delegate object to respond to movie capture events.
    private var delegate: MovieCaptureDelegate?
    
    // The interval at which to update the recording time.
    private let refreshInterval = TimeInterval(0.25)
    private var timerCancellable: AnyCancellable?
    
    // A Boolean value that indicates whether the currently selected camera's
    // active format supports HDR.
    private var isHDRSupported = false
    /// 지금 카메라가 찍을 수 있는 해상도 · 프레임률
    private var videoModes = Set<VideoMode>()

    // MARK: - Capturing a movie

    /// 재생 의도 메타데이터: 0 = 슬로 모션으로 재생
    private static var slowMotionPlaybackIntent: AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataFullFrameRatePlaybackIntent
        item.dataType = kCMMetadataBaseDataType_UInt8 as String
        item.value = NSNumber(value: UInt8(0))
        return item
    }

    /// Starts movie recording. 슬로 모션이면 사진 앱에 느리게 재생할 영상임을 알림
    func startRecording(isSlowMotion: Bool = false) {
        // Return early if already recording.
        guard !movieOutput.isRecording else { return }

        // Start a timer to update the recording time.
        startMonitoringDuration()

        let delegate = MovieCaptureDelegate()
        self.delegate = delegate
        movieOutput.metadata = isSlowMotion ? [Self.slowMotionPlaybackIntent] : nil
        movieOutput.startRecording(to: URL.movieFileURL, recordingDelegate: delegate)
    }
    
    /// Stops movie recording.
    /// - Returns: A `Movie` object that represents the captured movie.
    func stopRecording() async throws -> Movie {
        // Use a continuation to adapt the delegate-based capture API to an async interface.
        return try await withCheckedThrowingContinuation { continuation in
            // Set the continuation on the delegate to handle the capture result.
            delegate?.continuation = continuation
            
            /// Stops recording, which causes the output to call the `MovieCaptureDelegate` object.
            movieOutput.stopRecording()
            stopMonitoringDuration()
        }
    }
    
    // MARK: - Movie capture delegate
    /// A delegate object that responds to the capture output finalizing movie recording.
    private class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        
        var continuation: CheckedContinuation<Movie, Error>?
        
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error {
                // If an error occurs, throw it to the caller.
                continuation?.resume(throwing: error)
            } else {
                // Return a new movie object.
                continuation?.resume(returning: Movie(url: outputFileURL))
            }
        }
    }
    
    // MARK: - Monitoring recorded duration
    
    // Starts a timer to update the recording time.
    private func startMonitoringDuration() {
        captureActivity = .movieCapture()
        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Poll the movie output for its recorded duration.
                let duration = movieOutput.recordedDuration.seconds
                captureActivity = .movieCapture(duration: duration)
            }
    }
    
    /// Stops the timer and resets the time to `CMTime.zero`.
    private func stopMonitoringDuration() {
        timerCancellable?.cancel()
        captureActivity = .idle
    }
    
    func updateConfiguration(for device: AVCaptureDevice) {
        // The app supports HDR video capture if the active format supports it.
        isHDRSupported = device.activeFormat10BitVariant != nil
        videoModes = device.supportedVideoModes

        // The output has a video connection only while the session contains it, which is the
        // case in video capture mode. Adding the output creates a new connection, so the service
        // configures it here rather than when recording starts.
        guard let connection = movieOutput.connection(with: .video) else { return }

        // Configure the connection for HEVC capture.
        if movieOutput.availableVideoCodecTypes.contains(.hevc) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
        }

        // Stabilize the video this output records. Stabilization crops the video to leave room to
        // correct for camera motion, so configuring it here, rather than when recording starts,
        // avoids changing the framing at the moment recording begins. Passing `auto` lets the
        // system choose a mode that suits the active format and frame rate.
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }

    // MARK: - Configuration
    /// Returns the capabilities for this capture service.
    var capabilities: CaptureCapabilities {
        CaptureCapabilities(isHDRSupported: isHDRSupported, videoModes: videoModes)
    }
}
