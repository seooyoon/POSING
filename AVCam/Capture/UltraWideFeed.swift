//
//  UltraWideFeed.swift
//  포징
//
//  미리보기 바깥 배경용 초광각 프레임 (docs/02_UI.md 5절).
//  기본 카메라처럼 더 넓은 초광각 렌즈 화면으로 미리보기 바깥을 채운다.
//  트리플 카메라의 초광각 포트를 AVCaptureMultiCamSession에서 따로 받아 PreviewBackdrop에 바로 그린다.
//

import AVFoundation
import os

final class UltraWideFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    let output = AVCaptureVideoDataOutput()

    /// 배경에 프레임을 넘길 곳 (화면이 바깥을 보일 때만 연결)
    private let backdrop = OSAllocatedUnfairLock<AVSampleBufferVideoRenderer?>(uncheckedState: nil)
    private let queue = DispatchQueue(label: "com.seoyun.posing.ultraWide")

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        // 화면 크기 프레임만 받음 (메모리 · 발열)
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    /// 배경 연결 (nil이면 끊음)
    func setBackdrop(_ renderer: AVSampleBufferVideoRenderer?) {
        backdrop.withLockUnchecked { $0 = renderer }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let renderer = backdrop.withLockUnchecked({ $0 }) else { return }
        // 오류로 멈추면 비우고 다시 받음
        if renderer.status == .failed || renderer.requiresFlushToResumeDecoding {
            renderer.flush()
        }
        guard renderer.isReadyForMoreMediaData, !sampleBuffer.sampleAttachments.isEmpty else { return }
        // 시간표 없이 들어오는 대로 바로 표시
        sampleBuffer.sampleAttachments[0][.displayImmediately] = true
        renderer.enqueue(sampleBuffer)
    }
}
