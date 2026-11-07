//
//  FilteredPreviewFeed.swift
//  포징
//
//  보정 미리보기용 프레임 출력 (docs/05_TECH_NOTES.md 4절).
//  카메라 색감 · 스타일로 보정할 때만 세션에 붙이고, 가장 최근 프레임 하나만 들고 있다.
//  사진 저장과 같은 필터 체인(PhotoFilter.filtered)을 쓴다.
//

import AVFoundation
import CoreImage
import UIKit
import os

final class FilteredPreviewFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    let output = AVCaptureVideoDataOutput()

    private struct State {
        var image: CIImage?
        /// 시뮬레이터 샘플 이미지 (프레임이 없을 때 대신 씀)
        var staticImage: CIImage?
        var lutURL: URL?
        var lut: CubeLUT?
        var style: StyleSelection?
        /// 새 프레임 · 새 보정이 들어올 때마다 1씩 늘어남. 그리는 쪽은 바뀌었을 때만 그림 (발열)
        var generation = 0

        var isFiltering: Bool { lut != nil || style != nil }
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "com.seoyun.posing.filteredPreview")

    /// 보정을 켜고 끌 때 화면에 알림 (메인 스레드)
    @MainActor var onChange: ((Bool) -> Void)?

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        // 48MP 형식이어도 화면 크기 프레임만 받음 (전체 크기 프레임은 메모리 · 발열이 큼)
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    var isFiltering: Bool { state.withLock { $0.isFiltering } }

    /// 보정 설정. LUT는 주소가 바뀔 때만 다시 읽음
    @MainActor
    func configure(lutURL: URL?, style: StyleSelection?) {
        let current = state.withLock { $0.lutURL == lutURL ? $0.lut : nil }
        let lut = current ?? lutURL.flatMap(CubeLUT.init(contentsOf:))
        let isFiltering = state.withLock { state in
            state.lutURL = lutURL
            state.lut = lut
            state.style = style?.changesImage == true ? style : nil
            // 끄면 지난 프레임을 버려서 다시 켤 때 옛 화면이 잠깐 보이지 않게
            if !state.isFiltering { state.image = nil }
            state.generation &+= 1
            return state.isFiltering
        }
        onChange?(isFiltering)
    }

    /// 시뮬레이터: 샘플 이미지를 프레임 대신 씀
    func setStaticImage(_ image: UIImage?) {
        let ciImage = image.flatMap { CIImage(image: $0) }
        state.withLock { state in
            state.staticImage = ciImage
            state.generation &+= 1
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        state.withLock { state in
            guard state.isFiltering else { return }
            state.image = image
            state.generation &+= 1
        }
    }

    /// 지난번 이후 바뀐 보정 프레임. 보정이 없거나, 프레임이 없거나, 바뀐 것이 없으면 nil
    func filteredFrame(after generation: Int) -> (image: CIImage, generation: Int)? {
        let current = state.withLock { $0 }
        guard current.isFiltering, current.generation != generation,
              let image = current.image ?? current.staticImage else { return nil }
        return (PhotoFilter.filtered(image, lut: current.lut, style: current.style), current.generation)
    }
}
