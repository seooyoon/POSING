//
//  TimelapseCapture.swift
//  포징
//
//  타임랩스: 카메라 프레임을 일정 간격으로 골라 30fps 영상으로 쓴다 (docs/05_TECH_NOTES.md).
//  프레임은 전용 큐에서 처리하고, 포즈 · MY 레이어는 이 경로에 들어오지 않는다.
//

@preconcurrency import AVFoundation
import Combine

final class TimelapseCapture: OutputService {

    @Published private(set) var captureActivity: CaptureActivity = .idle

    let output = AVCaptureVideoDataOutput()

    private let recorder = TimelapseRecorder()
    private let queue = DispatchQueue(label: "com.seoyun.posing.timelapse")
    private var timerCancellable: AnyCancellable?

    init() {
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(recorder, queue: queue)
    }

    var capabilities: CaptureCapabilities { .unknown }

    func updateConfiguration(for device: AVCaptureDevice) {
        guard let connection = output.connection(with: .video),
              connection.isVideoStabilizationSupported else { return }
        connection.preferredVideoStabilizationMode = .auto
    }

    func startRecording() {
        guard !captureActivity.isRecording else { return }
        let recorder = recorder
        queue.async { recorder.start() }
        let startDate = Date.now
        captureActivity = .movieCapture()
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.captureActivity = .movieCapture(duration: Date.now.timeIntervalSince(startDate))
            }
    }

    func stopRecording() async throws -> Movie {
        timerCancellable?.cancel()
        captureActivity = .idle
        let recorder = recorder
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                recorder.finish { continuation.resume(with: $0) }
            }
        }
    }
}

/// 프레임을 골라 파일에 쓰는 쪽. 모든 값은 TimelapseCapture의 큐에서만 건드린다
private final class TimelapseRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private let interval = CMTime(seconds: AppDefaults.timelapseInterval, preferredTimescale: 600)
    private let outputFrameRate = AppDefaults.timelapseFrameRate

    private var isRecording = false
    private var url: URL?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var size: CMVideoDimensions?
    private var lastCaptureTime: CMTime?
    private var frameCount: Int64 = 0

    func start() {
        url = .movieFileURL
        writer = nil
        input = nil
        size = nil
        lastCaptureTime = nil
        frameCount = 0
        isRecording = true
    }

    func finish(completion: @escaping @Sendable (Result<Movie, Error>) -> Void) {
        isRecording = false
        guard let writer, let input, let url else {
            // 프레임이 하나도 들어오기 전에 멈춤
            completion(.failure(CameraError.setupFailed))
            return
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: outputTime(of: frameCount))
        writer.finishWriting {
            if writer.status == .completed {
                completion(.success(Movie(url: url)))
            } else {
                completion(.failure(writer.error ?? CameraError.setupFailed))
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        let time = sampleBuffer.presentationTimeStamp
        if let lastCaptureTime, time - lastCaptureTime < interval { return }
        guard let dimensions = sampleBuffer.formatDescription?.dimensions else { return }
        if writer == nil { makeWriter(size: dimensions) }
        // 녹화 중 폰을 돌려 크기가 바뀐 프레임은 건너뜀
        guard dimensions == size, let input, input.isReadyForMoreMediaData,
              let frame = retimed(sampleBuffer) else { return }
        if input.append(frame) {
            lastCaptureTime = time
            frameCount += 1
        }
    }

    private func makeWriter(size: CMVideoDimensions) {
        guard let url, let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
        self.size = size
    }

    /// 영상 시간표로 옮긴 프레임: n번째 프레임은 n / 30초
    private func retimed(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(duration: outputTime(of: 1),
                                        presentationTimeStamp: outputTime(of: frameCount),
                                        decodeTimeStamp: .invalid)
        var copy: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer,
                                                           sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                                           sampleBufferOut: &copy)
        return status == noErr ? copy : nil
    }

    private func outputTime(of frame: Int64) -> CMTime {
        CMTime(value: frame, timescale: CMTimeScale(outputFrameRate))
    }
}
