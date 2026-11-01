//
//  ZoomState.swift
//  포징
//
//  화면에 보이는 배율(표시 배율)과 배율 버튼 · 접사 상태 (docs/01_SPEC.md 7절, docs/05_TECH_NOTES.md 1 · 2절).
//  표시 배율 = 장치 videoZoomFactor × displayVideoZoomFactorMultiplier (트리플 카메라는 0.5).
//

import Foundation

struct ZoomState: Equatable, Sendable {

    /// 기본 카메라 배율 버튼 값
    static let presetValues: [CGFloat] = [0.5, 1, 2, 5]
    /// 다이얼 최대 표시 배율
    static let maxDisplayFactor: CGFloat = 25

    /// 지금 표시 배율
    var displayFactor: CGFloat = 1
    var range: ClosedRange<CGFloat> = 1...1
    /// 이 카메라에서 쓸 수 있는 배율 버튼. 비어 있으면 배율 버튼을 숨김 (전면 카메라 등)
    var presets: [CGFloat] = []
    /// 1× 이상인데 초광각 렌즈로 가까이 찍는 중
    var isMacroActive = false
    /// 자동 접사 전환 켜짐 (꽃 버튼으로 끔)
    var isAutoMacroEnabled = true
    /// 렌즈 자동 전환을 바꿀 수 있음. 안 되면 꽃 버튼을 숨김
    var supportsMacroSwitching = false
    /// 전면 카메라: 배율 버튼 대신 화각 버튼 (넓게 ↔ 가깝게)
    var isFrontCamera = false
    var isFrontWide = false

    static let unavailable = ZoomState()

    var isAvailable: Bool { !presets.isEmpty }

    /// 꽃 버튼은 접사 중이거나, 접사 전환을 꺼 둔 동안 보임
    var showsMacroButton: Bool { supportsMacroSwitching && (isMacroActive || !isAutoMacroEnabled) }

    /// 지금 배율이 속한 버튼 (지금 배율보다 작거나 같은 버튼 중 가장 큰 것)
    var activePreset: CGFloat? {
        presets.last { $0 <= displayFactor + 0.05 } ?? presets.first
    }

    /// 버튼 · 다이얼 글자: `.5`, `1`, `1.4`, `7`
    static func label(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded < 1 {
            return String(format: ".%d", Int((rounded * 10).rounded()))
        }
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
