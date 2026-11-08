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
    /// 1× 이상에서 피사체가 가까움 (꽃을 끈 동안 꽃 버튼을 보일지)
    var isSubjectClose = false
    /// 전면 카메라: 배율 버튼 대신 화각 버튼 (넓게 ↔ 가깝게)
    var isFrontCamera = false
    var isFrontWide = false

    static let unavailable = ZoomState()

    var isAvailable: Bool { !presets.isEmpty }

    /// 꽃 버튼이 보임. 접사 중이거나, 접사 전환을 꺼 둔 채 아직 가까이 있을 때.
    /// 렌즈가 잠깐씩 바뀌어 깜빡이지 않게 ZoomController가 한동안 유지해서 넣음
    var showsMacroButton = false

    /// 꽃 버튼을 보일 조건 (유지 시간 없이 지금 값만). 꽃을 끈 뒤 멀어지면 사라지고, 다시 가까워지면 꺼진 모양으로 나타남.
    /// 꽃을 끈 동안은 렌즈 종류와 상관없이 초점 거리로만 판단 (끈 직후 초광각이 남아 있어도 멀어지면 사라지게)
    var wantsMacroButton: Bool {
        isAutoMacroEnabled ? isMacroActive : (supportsMacroSwitching && isSubjectClose)
    }

    /// 지금 배율이 속한 버튼 (지금 배율보다 작거나 같은 버튼 중 가장 큰 것)
    var activePreset: CGFloat? {
        presets.last { $0 <= displayFactor + 0.05 } ?? presets.first
    }

    /// 1× 버튼을 다시 누를 때 도는 화각: 24 → 28 → 35mm
    static let mainLensFactors: [CGFloat] = [1, 1.2, 1.5]

    /// 이 배율 다음 화각
    static func nextMainLensFactor(after factor: CGFloat) -> CGFloat {
        mainLensFactors.first { $0 > factor + 0.05 } ?? 1
    }

    /// 화각 이름이 있는 배율의 mm (기본 카메라에 표시되는 값만)
    static func millimeters(_ factor: CGFloat) -> Int? {
        let known: [(CGFloat, Int)] = [(0.5, 13), (1, 24), (1.2, 28), (1.5, 35), (2, 48), (5, 120)]
        return known.first { abs($0.0 - factor) < 0.05 }?.1
    }

    /// 지금 배율 글자: 1 아래는 앞에 0을 붙임 (`0.5`, `1.4`, `7`)
    static func activeLabel(_ value: CGFloat) -> String {
        value < 0.95 ? String(format: "%.1f", value) : label(value)
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
