//
//  StyleState.swift
//  포징
//
//  스타일 화면의 상태: 고른 스타일과 스타일마다 바꾼 값 (docs/01_SPEC.md 8절 스타일 화면).
//  저장하지 않아 앱을 다시 켜면 표준 · 기본값으로 돌아간다.
//

import Foundation

@MainActor
@Observable
final class StyleState {

    private(set) var style: PhotoStyle
    private var values: [PhotoStyle: StyleValues] = [:]

    init() {
        style = .standard
    }

    var current: StyleValues { values[style] ?? style.preset.defaults }

    var selection: StyleSelection { StyleSelection(style: style, values: current) }

    var index: Int { PhotoStyle.allCases.firstIndex(of: style) ?? 0 }

    /// 왼쪽으로 밀면 다음 스타일. 끝에서는 멈춤
    func step(by offset: Int) {
        let styles = PhotoStyle.allCases
        let next = min(max(index + offset, 0), styles.count - 1)
        guard styles[next] != style else { return }
        style = styles[next]
    }

    /// 조절 패드: 가로 = 색상, 세로 = 톤 (-100~100)
    func setPad(tone: Double, color: Double) {
        var value = current
        value.tone = Self.clamped(tone, -100...100)
        value.color = Self.clamped(color, -100...100)
        update(value)
    }

    func setPalette(_ palette: Double) {
        var value = current
        value.palette = Self.clamped(palette, 0...100)
        update(value)
    }

    /// 패드를 두 번 탭하면 그 스타일 기본값으로
    func resetCurrent() {
        update(style.preset.defaults)
    }

    /// 스타일 초기화 버튼: 표준 스타일 · 모든 스타일 값 기본으로
    func resetAll() {
        values.removeAll()
        style = .standard
    }

    /// 표준 스타일이고 바꾼 값이 하나도 없음 (초기화 버튼을 흐리게)
    var isAllDefault: Bool {
        style == .standard && values.allSatisfy { $0.value == $0.key.preset.defaults }
    }

    private func update(_ value: StyleValues) {
        guard value != current else { return }
        values[style] = value
    }

    private static func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value.rounded(), range.lowerBound), range.upperBound)
    }
}
