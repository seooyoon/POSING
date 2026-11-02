//
//  ZoomController.swift
//  포징
//
//  후면 트리플 카메라의 배율 · 접사 전환. CaptureService 액터 안에서만 부른다 (메인 스레드 밖).
//  카메라 컨트롤 버튼으로 배율을 바꿔도 videoZoomFactor 관찰로 화면 값이 따라온다.
//

@preconcurrency import AVFoundation
import Combine

final class ZoomController {

    @Published private(set) var state = ZoomState.unavailable

    /// 버튼을 누를 때 부드럽게 바뀌는 속도
    private static let rampRate: Float = 12
    /// 전면 '가깝게' 배율 (기본 카메라 셀카 기본 화각). '넓게'는 장치 최소 배율. 실기기 확인
    private static let frontCloseZoomFactor: CGFloat = 1.25

    private var device: AVCaptureDevice?
    private var observations: [NSKeyValueObservation] = []
    private var isAutoMacroEnabled = true

    /// KVO는 아무 스레드에서나 오므로 직접 갱신하지 않고 CaptureService 액터로 넘김
    var onDeviceChange: (@Sendable () -> Void)?

    /// 카메라가 바뀔 때마다 연결. 접사 전환은 다시 자동으로
    func attach(to device: AVCaptureDevice) {
        self.device = device
        isAutoMacroEnabled = true
        applyDefaultZoom()
        observations = [
            device.observe(\.videoZoomFactor, options: [.new]) { [weak self] _, _ in
                self?.onDeviceChange?()
            },
            device.observe(\.activePrimaryConstituent, options: [.new]) { [weak self] _, _ in
                self?.onDeviceChange?()
            },
        ]
        refresh()
    }

    /// 전면은 기본 카메라처럼 '가깝게', 후면 트리플 카메라는 1× (장치 기본값은 0.5×).
    /// 모드 전환 · 형식 변경으로 장치 배율이 처음 값으로 돌아갈 때도 부른다
    func applyDefaultZoom() {
        guard let device else { return }
        if device.position == .front {
            setZoomFactor(Self.frontCloseZoomFactor, on: device, animated: false)
        } else if device.isVirtualDevice {
            setZoomFactor(1 / device.displayVideoZoomFactorMultiplier, on: device, animated: false)
        }
    }

    func setZoom(_ displayFactor: CGFloat, animated: Bool) {
        guard let device, state.isAvailable else { return }
        let multiplier = device.displayVideoZoomFactorMultiplier
        let maxFactor = min(device.maxAvailableVideoZoomFactor, ZoomState.maxDisplayFactor / multiplier)
        setZoomFactor(min(displayFactor / multiplier, maxFactor), on: device, animated: animated)
    }

    /// 전면 화각 버튼
    func setFrontWide(_ isWide: Bool) {
        guard let device, device.position == .front else { return }
        setZoomFactor(isWide ? device.minAvailableVideoZoomFactor : Self.frontCloseZoomFactor, on: device, animated: true)
    }

    private func setZoomFactor(_ factor: CGFloat, on device: AVCaptureDevice, animated: Bool) {
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        do {
            try device.lockForConfiguration()
            if animated {
                device.ramp(toVideoZoomFactor: clamped, withRate: Self.rampRate)
            } else {
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = clamped
            }
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to set zoom. \(error)")
        }
    }

    /// 꽃 버튼: 끄면 배율을 바꿀 때만 렌즈가 바뀌어 가까워도 초광각으로 넘어가지 않음
    func setAutoMacroEnabled(_ isEnabled: Bool) {
        guard let device, supportsMacroSwitching(device) else { return }
        do {
            try device.lockForConfiguration()
            if isEnabled {
                device.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
            } else {
                device.setPrimaryConstituentDeviceSwitchingBehavior(.restricted, restrictedSwitchingBehaviorConditions: .videoZoomChanged)
            }
            device.unlockForConfiguration()
            isAutoMacroEnabled = isEnabled
        } catch {
            logger.debug("Unable to change macro switching. \(error)")
        }
        refresh()
    }

    /// 렌즈 자동 전환을 바꿀 수 있는 카메라인지
    private func supportsMacroSwitching(_ device: AVCaptureDevice) -> Bool {
        device.isVirtualDevice && device.primaryConstituentDeviceSwitchingBehavior != .unsupported
    }

    /// CaptureService 액터 안에서만 부른다
    func refresh() {
        guard let device else {
            state = .unavailable
            return
        }
        // 전면은 배율 버튼 · 다이얼 없이 화각 버튼만
        if device.position == .front {
            state = ZoomState(isFrontCamera: true,
                              isFrontWide: device.videoZoomFactor < Self.frontCloseZoomFactor - 0.01)
            return
        }
        // 렌즈가 하나인 후면 카메라는 배율 버튼 없음
        guard device.isVirtualDevice else {
            state = .unavailable
            return
        }
        let multiplier = device.displayVideoZoomFactorMultiplier
        let display = device.videoZoomFactor * multiplier
        let range = device.minAvailableVideoZoomFactor * multiplier
            ... min(device.maxAvailableVideoZoomFactor * multiplier, ZoomState.maxDisplayFactor)
        let isUltraWideActive = device.activePrimaryConstituent?.deviceType == .builtInUltraWideCamera
        state = ZoomState(
            displayFactor: display,
            range: range,
            presets: ZoomState.presetValues.filter { range.contains($0) },
            isMacroActive: isUltraWideActive && display >= 0.99,
            isAutoMacroEnabled: isAutoMacroEnabled,
            supportsMacroSwitching: supportsMacroSwitching(device)
        )
    }
}
