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

    private var device: AVCaptureDevice?
    private var observations: [NSKeyValueObservation] = []
    private var isAutoMacroEnabled = true

    /// 카메라가 바뀔 때마다 연결. 접사 전환은 다시 자동으로
    func attach(to device: AVCaptureDevice) {
        self.device = device
        isAutoMacroEnabled = true
        observations = [
            device.observe(\.videoZoomFactor, options: [.new]) { [weak self] _, _ in
                self?.refresh()
            },
            device.observe(\.activePrimaryConstituent, options: [.new]) { [weak self] _, _ in
                self?.refresh()
            },
        ]
        refresh()
    }

    func setZoom(_ displayFactor: CGFloat, animated: Bool) {
        guard let device, state.isAvailable else { return }
        let multiplier = device.displayVideoZoomFactorMultiplier
        let maxFactor = min(device.maxAvailableVideoZoomFactor, ZoomState.maxDisplayFactor / multiplier)
        let factor = min(max(displayFactor / multiplier, device.minAvailableVideoZoomFactor), maxFactor)
        do {
            try device.lockForConfiguration()
            if animated {
                device.ramp(toVideoZoomFactor: factor, withRate: Self.rampRate)
            } else {
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to set zoom. \(error)")
        }
    }

    /// 꽃 버튼: 끄면 배율을 바꿀 때만 렌즈가 바뀌어 가까워도 초광각으로 넘어가지 않음
    func setAutoMacroEnabled(_ isEnabled: Bool) {
        guard let device, device.isVirtualDevice else { return }
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

    private func refresh() {
        // 렌즈가 하나인 카메라(전면 등)는 배율 버튼 없음. 전면 화각 버튼은 #16에서
        guard let device, device.isVirtualDevice, device.position == .back else {
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
            isAutoMacroEnabled: isAutoMacroEnabled
        )
    }
}
