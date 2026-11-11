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
    /// 꽃을 끈 동안 렌즈 초점이 가장 가까운 쪽에 붙어 있음 (꽃 버튼을 보일지)
    private var isSubjectClose = false
    /// 꽃 버튼을 이 시각까지 유지 (접사 렌즈가 잠깐 바뀌어도 버튼이 깜빡이지 않게)
    private var macroButtonHoldUntil = Date.distantPast

    /// KVO는 아무 스레드에서나 오므로 직접 갱신하지 않고 CaptureService 액터로 넘김
    var onDeviceChange: (@Sendable () -> Void)?

    /// 카메라가 바뀔 때마다 연결. 접사 전환은 다시 자동으로
    func attach(to device: AVCaptureDevice) {
        self.device = device
        isAutoMacroEnabled = true
        isSubjectClose = false
        macroButtonHoldUntil = .distantPast
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
                // 배율을 살짝 움직였다 되돌려 지금 배율의 렌즈(1×면 메인)로 바로 돌아가게 함
                let zoom = device.videoZoomFactor
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = min(zoom + 0.01, device.maxAvailableVideoZoomFactor)
                device.videoZoomFactor = zoom
            }
            device.unlockForConfiguration()
            isAutoMacroEnabled = isEnabled
            // 끄는 순간은 가까이 있는 중이므로 버튼을 유지하고, 1× 렌즈 초점이 멀어지면 숨김
            if !isEnabled { isSubjectClose = true }
        } catch {
            logger.debug("Unable to change macro switching. \(error)")
        }
        refresh()
    }

    /// 꽃을 끈 동안 지금 렌즈의 초점 위치로 가까움을 다시 판단 (CaptureService가 주기적으로 부름).
    /// 초점 위치 KVO는 렌즈별로 잘 오지 않아 직접 읽음
    func updateSubjectDistance() {
        // 꽃 버튼 유지 시간이 끝났는지도 여기서 다시 계산
        defer { refresh() }
        guard let device, !isAutoMacroEnabled, device.position == .back else { return }
        let position = (device.activePrimaryConstituent ?? device).lensPosition
        let next = isSubjectClose ? position < AppDefaults.macroFarLensPosition
                                  : position <= AppDefaults.macroCloseLensPosition
        guard next != isSubjectClose else { return }
        logger.notice("[Macro] subject \(next ? "close" : "far", privacy: .public) at lens position \(position, privacy: .public)")
        isSubjectClose = next
    }

    /// 렌즈 자동 전환을 바꿀 수 있는 카메라인지
    private func supportsMacroSwitching(_ device: AVCaptureDevice) -> Bool {
        device.isVirtualDevice && device.primaryConstituentDeviceSwitchingBehavior != .unsupported
    }

    /// CaptureService 액터 안에서만 부른다. 값이 같으면 다시 알리지 않음 (화면 갱신을 줄임)
    func refresh() {
        let next = currentState()
        if next != state { state = next }
    }

    private func currentState() -> ZoomState {
        guard let device else { return .unavailable }
        // 전면은 배율 버튼 · 다이얼 없이 화각 버튼만
        if device.position == .front {
            return ZoomState(isFrontCamera: true,
                             isFrontWide: device.videoZoomFactor < Self.frontCloseZoomFactor - 0.01)
        }
        // 메인 렌즈 하나(48MP 사진): 1 · 2 버튼과 확대만 (2는 확대)
        guard device.isVirtualDevice else {
            let range = device.minAvailableVideoZoomFactor
                ... min(device.maxAvailableVideoZoomFactor, ZoomState.maxDisplayFactor)
            return ZoomState(displayFactor: device.videoZoomFactor, range: range,
                             presets: ZoomState.mainLensOnlyPresets.filter { range.contains($0) })
        }
        let multiplier = device.displayVideoZoomFactorMultiplier
        let display = device.videoZoomFactor * multiplier
        let range = device.minAvailableVideoZoomFactor * multiplier
            ... min(device.maxAvailableVideoZoomFactor * multiplier, ZoomState.maxDisplayFactor)
        let isUltraWideActive = device.activePrimaryConstituent?.deviceType == .builtInUltraWideCamera
        var state = ZoomState(
            displayFactor: display,
            range: range,
            presets: ZoomState.presetValues.filter { range.contains($0) },
            isMacroActive: isUltraWideActive && display >= 0.99,
            isAutoMacroEnabled: isAutoMacroEnabled,
            supportsMacroSwitching: supportsMacroSwitching(device),
            isSubjectClose: isSubjectClose && display >= 0.99
        )
        // 조건이 맞으면 유지 시간을 늘리고, 잠깐 풀려도 유지 시간 동안은 계속 보임
        // 1× 미만(초광각 화면)에서는 유지하지 않고 바로 숨김
        let now = Date.now
        if display < 0.99 {
            macroButtonHoldUntil = .distantPast
        } else if state.wantsMacroButton {
            macroButtonHoldUntil = now.addingTimeInterval(AppDefaults.macroButtonHoldDuration)
        }
        state.showsMacroButton = display >= 0.99
            && (state.wantsMacroButton || now < macroButtonHoldUntil)
        return state
    }
}
