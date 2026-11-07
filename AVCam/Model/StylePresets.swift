//
//  StylePresets.swift
//  포징
//
//  스타일 6개의 이름 · 기본값 · 룩 숫자 (docs/01_SPEC.md 8절, docs/05_TECH_NOTES.md 4절).
//  참고 화면(docs/reference/style_*.png)과 같은 장면을 찍어 비교하며 이 파일의 숫자만 고친다.
//

import Foundation

/// 스타일의 기본 룩. 팔레트 값만큼 원본과 섞임
struct StyleLook: Sendable {
    /// 채도 배율 (1 = 그대로)
    var saturation = 1.0
    /// 대비 배율 (1 = 그대로)
    var contrast = 1.0
    /// 밝기 더하기 (-1~1, 0 = 그대로)
    var brightness = 0.0
    /// 색온도 (켈빈). 플러스 = 차갑게, 마이너스 = 따뜻하게
    var coolness = 0.0
    /// 흑백 스타일. 팔레트와 상관없이 항상 흑백
    var isMono = false
}

struct StylePreset: Sendable {
    let name: String
    /// 카드 위 분류 캡슐 (색조 · 무드)
    let category: String
    let defaults: StyleValues
    /// 표준은 팔레트 슬라이더 없음
    let hasPalette: Bool
    let look: StyleLook
}

extension PhotoStyle {

    var preset: StylePreset {
        switch self {
        case .standard:
            StylePreset(name: "표준", category: "색조",
                        defaults: StyleValues(tone: 0, color: 0, palette: 0), hasPalette: false,
                        look: StyleLook())
        case .neutral:
            StylePreset(name: "뉴트럴", category: "색조",
                        defaults: StyleValues(tone: 40, color: -10, palette: 80), hasPalette: true,
                        look: StyleLook(saturation: 0.88, contrast: 0.95, brightness: 0.04, coolness: 600))
        case .dramatic:
            StylePreset(name: "드라마틱", category: "무드",
                        defaults: StyleValues(tone: -76, color: 19, palette: 100), hasPalette: true,
                        look: StyleLook(saturation: 0.7, contrast: 1.05, brightness: -0.01, coolness: 900))
        case .elegant:
            StylePreset(name: "우아하게", category: "무드",
                        defaults: StyleValues(tone: 68, color: -15, palette: 100), hasPalette: true,
                        look: StyleLook(saturation: 0.65, contrast: 0.85, brightness: 0.06, coolness: 300))
        case .softMono:
            StylePreset(name: "부드러운 흑백 대비", category: "무드",
                        defaults: StyleValues(tone: 40, color: 0, palette: 50), hasPalette: true,
                        look: StyleLook(contrast: 0.8, brightness: 0.06, isMono: true))
        case .starkMono:
            StylePreset(name: "강렬한 흑백 대비", category: "무드",
                        defaults: StyleValues(tone: -100, color: 0, palette: 50), hasPalette: true,
                        look: StyleLook(contrast: 1.15, isMono: true))
        }
    }

    var isStandard: Bool { self == .standard }
}

extension StyleSelection {
    static let standard = StyleSelection(style: .standard, values: PhotoStyle.standard.preset.defaults)

    /// 표준이고 톤 · 색상이 0이면 보정 없음
    var changesImage: Bool {
        !style.isStandard || values.tone != 0 || values.color != 0
    }
}

/// 고른 스타일 · 스타일마다 바꾼 값 저장 (앱을 다시 켜도 유지)
enum StyleLibrary {

    static func savedStyle() -> PhotoStyle {
        UserDefaults.standard.string(forKey: SettingsKeys.photoStyle).flatMap(PhotoStyle.init(rawValue:)) ?? .standard
    }

    /// 스타일마다 사용자가 바꾼 값. 없으면 기본값
    static func savedValues() -> [PhotoStyle: StyleValues] {
        guard let data = UserDefaults.standard.data(forKey: SettingsKeys.styleValues),
              let saved = try? JSONDecoder().decode([String: StyleValues].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in
            PhotoStyle(rawValue: key).map { ($0, value) }
        })
    }

    static func savedSelection() -> StyleSelection {
        let style = savedStyle()
        return StyleSelection(style: style, values: savedValues()[style] ?? style.preset.defaults)
    }

    static func save(style: PhotoStyle, values: [PhotoStyle: StyleValues]) {
        UserDefaults.standard.set(style.rawValue, forKey: SettingsKeys.photoStyle)
        let encoded = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(encoded), forKey: SettingsKeys.styleValues)
    }
}

/// 톤 · 색상 값을 필터 숫자로 바꾸는 비율 (값 ±100일 때의 변화량)
enum StyleTuning {
    /// 톤 마이너스: 그림자(25%)를 내리는 양 · 밝은 곳(75%)을 올리는 양 → 대비 강하게
    static let deepShadow = 0.08
    static let deepHighlight = 0.05
    /// 톤 플러스: 그림자 · 중간 · 밝은 곳을 올리는 양 → 밝고 부드럽게
    static let liftShadow = 0.1
    static let liftMidtone = 0.06
    static let liftHighlight = 0.03
    /// 색상: 채도 배율 변화 · 생동감 양
    static let saturation = 0.45
    static let vibrance = 0.3
    /// 흑백 스타일의 색상: 색온도 (켈빈). 플러스 = 따뜻하게
    static let monoWarmth = 1500.0
}
