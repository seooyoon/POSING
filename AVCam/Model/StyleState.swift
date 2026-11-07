//
//  StyleState.swift
//  포징
//
//  스타일 화면의 상태: 고른 스타일과 스타일마다 바꾼 값 (docs/01_SPEC.md 8절 스타일 화면).
//  바뀔 때마다 저장해서 앱을 다시 켜도 유지된다.
//

import Foundation

@MainActor
@Observable
final class StyleState {

    private(set) var style: PhotoStyle
    private var values: [PhotoStyle: StyleValues]

    init() {
        style = StyleLibrary.savedStyle()
        values = StyleLibrary.savedValues()
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
        save()
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

    private func update(_ value: StyleValues) {
        guard value != current else { return }
        values[style] = value
        save()
    }

    private func save() {
        StyleLibrary.save(style: style, values: values)
    }

    private static func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value.rounded(), range.lowerBound), range.upperBound)
    }
}
