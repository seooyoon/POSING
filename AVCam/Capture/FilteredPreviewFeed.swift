//
//  FilteredPreviewFeed.swift
//  포징
//
//  보정 미리보기용 프레임 출력 (docs/05_TECH_NOTES.md 4절). 사진 모드 + 보정이 있을 때만 세션에 붙는다.
//  카메라 색감 · 스타일로 보정할 때는 가장 최근 프레임 하나를 들고 있다가 사진 저장과 같은 필터 체인(PhotoFilter.filtered)으로 그림.
//  스타일을 바꾸면 기본 카메라처럼 세로 경계선이 화면을 가로지르며 이전 스타일 → 새 스타일로 바뀜 (StyleWipe)
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
        /// 디카 질감 (미리보기는 사람 밝게 없이 질감만)
        var finish: CameraFinish?
        /// 새 프레임 · 새 보정이 들어올 때마다 1씩 늘어남. 그리는 쪽은 바뀌었을 때만 그림 (발열)
        var generation = 0
        /// 마지막으로 받은 스타일 종류 (보정이 없는 표준도 포함). 종류가 바뀌면 경계선 효과
        var styleKind: PhotoStyle?
        var wipe: StyleWipe?

        /// 경계선이 지나가는 동안은 표준으로 돌아가도 계속 그림
        var isFiltering: Bool { lut != nil || style != nil || finish != nil || wipe != nil }
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "com.seoyun.posing.filteredPreview")

    /// 보정을 켜고 끌 때 화면에 알림 (메인 스레드)
    @MainActor var onChange: ((Bool) -> Void)?
    /// 경계선 효과가 끝남 (메인 스레드). 보정이 없어졌으면 프레임 출력을 떼도록 알림
    @MainActor var onWipeEnd: (() -> Void)?

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        // 48MP 형식이어도 화면 크기 프레임만 받음 (전체 크기 프레임은 메모리 · 발열이 큼)
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = true
        // 카메라 기본 형식(YUV) 그대로 받음: Core Image가 바로 읽음 (BGRA 변환 비용 절약)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
    }

    var isFiltering: Bool { state.withLock { $0.isFiltering } }

    /// 보정 설정. LUT는 주소가 바뀔 때만 다시 읽음
    @MainActor
    func configure(lutURL: URL?, style: StyleSelection?, finish: CameraFinish? = nil) {
        let current = state.withLock { $0.lutURL == lutURL ? $0.lut : nil }
        let lut = current ?? lutURL.flatMap(CubeLUT.init(contentsOf:))
        let isFiltering = state.withLock { state in
            // 스타일 종류가 바뀌면 이전 보정에서 새 보정으로 경계선이 지나감
            if let old = state.styleKind, let new = style?.style, old != new {
                state.wipe = StyleWipe(from: state.style, forward: new.index > old.index)
            }
            // 보정을 쓰지 않게 되면(비디오 · RAW · LIVE) 지나가던 경계선도 멈춤 (표준 스타일과는 다름)
            if style == nil { state.wipe = nil }
            state.styleKind = style?.style
            state.lutURL = lutURL
            state.lut = lut
            state.style = style?.changesImage == true ? style : nil
            state.finish = finish?.hasTexture == true ? finish : nil
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

    var isWiping: Bool { state.withLock { $0.wipe != nil } }

    /// 지난번 이후 바뀐 보정 프레임. 보정이 없거나, 프레임이 없거나, 바뀐 것이 없으면 nil.
    /// 경계선이 지나가는 동안은 매번 그림 (그리는 쪽에서 메인 스레드로 부름)
    @MainActor
    func filteredFrame(after generation: Int) -> (image: CIImage, generation: Int)? {
        let now = CACurrentMediaTime()
        let current = state.withLock { state in
            // 첫 프레임이 들어온 때부터 잼 (표준에서 바꾸면 프레임 출력이 붙을 때까지 조금 걸림)
            if state.wipe?.start == nil, state.image ?? state.staticImage != nil { state.wipe?.start = now }
            return state
        }
        guard current.isFiltering, current.generation != generation || current.wipe != nil,
              let image = current.image ?? current.staticImage else { return nil }
        // 노이즈 위치를 프레임마다 바꿔 화면에 무늬가 박혀 보이지 않게
        let grainOffset = CGPoint(x: Double.random(in: 0..<256), y: Double.random(in: 0..<256))
        let filtered = PhotoFilter.filtered(image, lut: current.lut, style: current.style,
                                            finish: current.finish, grainOffset: grainOffset)
        guard let wipe = current.wipe, let start = wipe.start else { return (filtered, current.generation) }
        let progress = (now - start) / AppDefaults.styleWipeDuration
        if progress >= 1 {
            finishWipe()
            // 표준으로 돌아와 보정이 없어졌으면 더 그리지 않음 (숨긴 화면이 다시 보이지 않게)
            return isFiltering ? (filtered, current.generation) : nil
        }
        let previous = PhotoFilter.filtered(image, lut: current.lut, style: wipe.from,
                                            finish: current.finish, grainOffset: grainOffset)
        return (wipe.composite(new: filtered, old: previous, extent: image.extent, progress: progress), current.generation)
    }

    /// 경계선이 끝나면 지금 보정만 남김. 보정이 없어졌으면 화면 · 프레임 출력도 끔
    @MainActor
    private func finishWipe() {
        let isFiltering = state.withLock { state in
            state.wipe = nil
            if !state.isFiltering { state.image = nil }
            state.generation &+= 1
            return state.isFiltering
        }
        onChange?(isFiltering)
        onWipeEnd?()
    }
}

/// 스타일 경계선 효과: 화면은 그대로, 세로 경계선이 가로질러 가며 새 스타일이 드러남.
/// 다음 스타일(왼쪽으로 밀기)은 오른쪽에서, 이전 스타일은 왼쪽에서 들어옴
struct StyleWipe {
    /// 이전 보정 (표준이면 nil)
    let from: StyleSelection?
    let forward: Bool
    var start: CFTimeInterval?

    func composite(new: CIImage, old: CIImage, extent: CGRect, progress: Double) -> CIImage {
        // 천천히 시작해 천천히 멈춤
        let eased = progress * progress * (3 - 2 * progress)
        let x = forward ? extent.maxX - extent.width * eased : extent.minX + extent.width * eased
        let newRect = forward
            ? CGRect(x: x, y: extent.minY, width: extent.maxX - x, height: extent.height)
            : CGRect(x: extent.minX, y: extent.minY, width: x - extent.minX, height: extent.height)
        let width = extent.width * AppDefaults.styleWipeLineRatio
        let line = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.85))
            .cropped(to: CGRect(x: x - width / 2, y: extent.minY, width: width, height: extent.height).intersection(extent))
        return line
            .composited(over: new.cropped(to: newRect))
            .composited(over: old.cropped(to: extent))
    }
}

private extension PhotoStyle {
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
