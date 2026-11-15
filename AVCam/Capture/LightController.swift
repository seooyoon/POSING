//
//  LightController.swift
//  포징
//
//  밝기(노출 보정)와 비디오 조명. CaptureService 액터 안에서만 부른다 (메인 스레드 밖).
//  기기의 노출 보정 값은 하나뿐이라, 더보기 메뉴 노출(고정)과 초점 표시 옆 밝기(초점을 다시 잡으면 0)를 더해서 넣는다.
//

@preconcurrency import AVFoundation

final class LightController {

    private var device: AVCaptureDevice?
    /// 더보기 메뉴 노출 (카메라 · 모드를 바꿔도 유지)
    private var compensation: Float = 0
    /// 초점 표시 옆 밝기
    private var focusBias: Float = 0
    private var torchMode = AVCaptureDevice.TorchMode.off

    /// 카메라가 바뀔 때마다 연결. 초점 밝기는 풀고 메뉴 노출 · 조명은 다시 적용
    func attach(to device: AVCaptureDevice) {
        // 전면에는 조명이 없어 새 기기에서 끌 수 없으므로, 이전 기기 조명을 먼저 끔
        if let previous = self.device, previous !== device {
            turnOffTorch(on: previous)
        }
        self.device = device
        focusBias = 0
        applyBias()
        applyTorch()
    }

    func setCompensation(_ value: Float) {
        compensation = value
        applyBias()
    }

    func setFocusBias(_ value: Float) {
        focusBias = value
        applyBias()
    }

    func resetFocusBias() {
        setFocusBias(0)
    }

    /// 비디오 모드 플래시 = 조명. 사진 모드에서는 끔
    func setTorch(_ mode: AVCaptureDevice.TorchMode) {
        torchMode = mode
        applyTorch()
    }

    private func applyBias() {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            let bias = min(max(compensation + focusBias, device.minExposureTargetBias), device.maxExposureTargetBias)
            device.setExposureTargetBias(bias)
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to set exposure bias. \(error)")
        }
    }

    private func turnOffTorch(on device: AVCaptureDevice) {
        guard device.hasTorch, device.torchMode != .off else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to turn off torch. \(error)")
        }
    }

    private func applyTorch() {
        guard let device, device.hasTorch else { return }
        let mode = device.isTorchModeSupported(torchMode) ? torchMode : .off
        guard device.torchMode != mode else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = mode
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to set torch. \(error)")
        }
    }
}

extension AVCaptureDevice.TorchMode {
    init(_ mode: FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        }
    }
}
