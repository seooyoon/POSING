//
//  StylePresets.swift
//  포징
//
//  스타일 16개의 이름 · 기본값 · 룩 숫자 (docs/01_SPEC.md 8절, docs/05_TECH_NOTES.md 4절).
//  기본값은 기본 카메라 화면에서 읽은 값. 새로 넣은 10개의 룩은 기본 카메라 화면 녹화의 색 분포에 맞춘 값.
//  같은 장면을 찍어 비교하며 이 파일의 숫자만 고친다.
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
    /// 빨강 · 초록 · 파랑 배율 (1 = 그대로). 스타일의 색 기운
    var gains = (red: 1.0, green: 1.0, blue: 1.0)
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
        case .coolRose:
            undertone("쿨 로즈", tone: 35, color: -10, palette: 75,
                      StyleLook(saturation: 0.93, contrast: 1.13, brightness: 0.061, gains: (1.13, 1.12, 1.37)))
        case .bright:
            undertone("브라이트", tone: 18, color: 0, palette: 100,
                      StyleLook(saturation: 1.23, contrast: 1.13, brightness: 0.056, gains: (1.09, 1.09, 1.17)))
        case .roseGold:
            undertone("로즈 골드", tone: -20, color: -20, palette: 75,
                      StyleLook(saturation: 1.05, contrast: 1.08, brightness: 0.04, gains: (1.08, 0.98, 0.97)))
        case .gold:
            undertone("골드", tone: 19, color: 48, palette: 85,
                      StyleLook(saturation: 1.0, contrast: 1.08, brightness: 0.041, gains: (1.12, 1.03, 1.05)))
        case .amber:
            undertone("앰버", tone: 20, color: 20, palette: 100,
                      StyleLook(saturation: 1.15, contrast: 1.09, brightness: 0.048, gains: (1.09, 1.0, 1.0)))
        case .standard:
            StylePreset(name: "표준", category: "색조",
                        defaults: StyleValues(tone: 0, color: 0, palette: 0), hasPalette: false,
                        look: StyleLook())
        case .neutral:
            StylePreset(name: "뉴트럴", category: "색조",
                        defaults: StyleValues(tone: 40, color: -10, palette: 80), hasPalette: true,
                        look: StyleLook(saturation: 0.88, contrast: 0.95, brightness: 0.04, coolness: 600))
        case .luminous:
            mood("화사하게", tone: -30, color: 33,
                 StyleLook(saturation: 1.01, contrast: 1.2, brightness: 0.05, gains: (0.97, 0.99, 1.21)))
        case .natural:
            mood("내추럴", tone: 65, color: 28,
                 StyleLook(saturation: 1.2, contrast: 1.11, brightness: 0.069, gains: (1.2, 1.25, 1.33)))
        case .radiant:
            mood("환하게", tone: 35, color: 30,
                 StyleLook(saturation: 1.06, contrast: 1.58, brightness: 0.181, gains: (0.9, 0.9, 1.59)))
        case .dramatic:
            StylePreset(name: "드라마틱", category: "무드",
                        defaults: StyleValues(tone: -76, color: 19, palette: 100), hasPalette: true,
                        look: StyleLook(saturation: 0.7, contrast: 1.05, brightness: -0.01, coolness: 900))
        case .quiet:
            mood("고요", tone: 50, color: 45,
                 StyleLook(saturation: 1.26, contrast: 1.41, brightness: 0.204, gains: (1.46, 1.17, 1.01)))
        case .cozy:
            mood("아늑하게", tone: -75, color: -20,
                 StyleLook(saturation: 1.35, contrast: 1.25, brightness: 0.092, gains: (1.17, 0.99, 1.39)))
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

    /// 색조 스타일 (팔레트 슬라이더 있음)
    private func undertone(_ name: String, tone: Double, color: Double, palette: Double, _ look: StyleLook) -> StylePreset {
        StylePreset(name: name, category: "색조",
                    defaults: StyleValues(tone: tone, color: color, palette: palette), hasPalette: true, look: look)
    }

    /// 무드 스타일 (기본 팔레트 100)
    private func mood(_ name: String, tone: Double, color: Double, _ look: StyleLook) -> StylePreset {
        StylePreset(name: name, category: "무드",
                    defaults: StyleValues(tone: tone, color: color, palette: 100), hasPalette: true, look: look)
    }
}

extension StyleSelection {
    static let standard = StyleSelection(style: .standard, values: PhotoStyle.standard.preset.defaults)

    /// 표준이고 톤 · 색상이 0이면 보정 없음
    var changesImage: Bool {
        !style.isStandard || values.tone != 0 || values.color != 0
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
