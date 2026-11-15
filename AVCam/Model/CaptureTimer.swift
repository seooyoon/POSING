//
//  CaptureTimer.swift
//  포징
//
//  타이머 카운트다운 (docs/01_SPEC.md 8절). 셔터를 누르면 세기 시작, 세는 중에 다시 누르면 취소.
//  실제 카메라와 시뮬레이터 가짜 카메라가 같이 쓴다.
//

import Foundation

@MainActor
@Observable
final class CaptureTimer {

    /// 남은 초. 세는 중이 아니면 nil
    private(set) var countdown: Int?
    private var task: Task<Void, Never>?

    /// 타이머가 꺼져 있으면 바로 찍고, 켜져 있으면 다 센 뒤 찍음
    func shutterPressed(duration: TimerDuration, capture: @escaping @MainActor () async -> Void) async {
        if task != nil {
            cancel()
            return
        }
        guard duration != .off else {
            await capture()
            return
        }
        task = Task {
            for remaining in stride(from: duration.rawValue, to: 0, by: -1) {
                countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            task = nil
            await capture()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        countdown = nil
    }
}
