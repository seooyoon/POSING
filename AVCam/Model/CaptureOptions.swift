//
//  CaptureOptions.swift
//  포징
//
//  더보기(•••) 메뉴 값: 플래시 · 타이머 · 노출 (docs/01_SPEC.md 8절).
//

import AVFoundation

/// 플래시: 자동 → 켬 → 끔
enum FlashMode: String, CaseIterable, Sendable {
    case auto
    case on
    case off

    var next: FlashMode {
        switch self {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
    }

    var symbolName: String {
        switch self {
        case .auto: "bolt.badge.automatic"
        case .on: "bolt.fill"
        case .off: "bolt.slash"
        }
    }

    /// 마지막 값 유지
    static var saved: FlashMode {
        FlashMode(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.flashMode) ?? "") ?? .auto
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: SettingsKeys.flashMode)
    }
}

/// 타이머: 끔 → 3초 → 5초 → 10초
enum TimerDuration: Int, CaseIterable, Sendable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var next: TimerDuration {
        switch self {
        case .off: .three
        case .three: .five
        case .five: .ten
        case .ten: .off
        }
    }

    var title: String {
        self == .off ? "타이머" : "\(rawValue)초"
    }

    static var saved: TimerDuration {
        TimerDuration(rawValue: UserDefaults.standard.integer(forKey: SettingsKeys.timerDuration)) ?? .off
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: SettingsKeys.timerDuration)
    }
}

/// 더보기 메뉴 노출: ±2, 1/3 단위. 앱을 다시 켜면 0 (기본 카메라와 같음)
enum ExposureCompensation {
    static let range: ClosedRange<Float> = -2...2
    static let step: Float = 1.0 / 3

    /// 가장 가까운 눈금으로
    static func snapped(_ value: Float) -> Float {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped / step).rounded() * step
    }

    /// `+0.7`, `-1.3`, `0.0`
    static func label(_ value: Float) -> String {
        let text = String(format: "%.1f", abs(value))
        if abs(value) < 0.05 { return "0.0" }
        return (value > 0 ? "+" : "-") + text
    }
}

/// 사진 비율: 4:3 → 16:9 → 1:1 (docs/01_SPEC.md 9절). 촬영은 항상 4:3으로 하고 저장 전에 가운데를 자름
enum PhotoAspect: String, CaseIterable, Sendable {
    case fourThree
    case sixteenNine
    case square

    var next: PhotoAspect {
        switch self {
        case .fourThree: .sixteenNine
        case .sixteenNine: .square
        case .square: .fourThree
        }
    }

    var label: String {
        switch self {
        case .fourThree: "4:3"
        case .sixteenNine: "16:9"
        case .square: "1:1"
        }
    }

    /// 세로 화면 미리보기의 높이 / 너비
    var portraitHeightRatio: CGFloat {
        switch self {
        case .fourThree: 4.0 / 3
        case .sixteenNine: 16.0 / 9
        case .square: 1
        }
    }

    /// 저장 사진의 긴 변 / 짧은 변. 4:3이면 자르지 않음 (nil)
    var cropLongToShort: CGFloat? {
        switch self {
        case .fourThree: nil
        case .sixteenNine: 16.0 / 9
        case .square: 1
        }
    }

    static var saved: PhotoAspect {
        PhotoAspect(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.photoAspect) ?? "") ?? .fourThree
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: SettingsKeys.photoAspect)
    }
}

/// 사진 형식 버튼 (docs/01_SPEC.md 7절): HEIF ↔ JPEG
enum PhotoCodec: String, CaseIterable, Sendable {
    case heif
    case jpeg

    var label: String { self == .heif ? "HEIF" : "JPEG" }

    var next: PhotoCodec { self == .heif ? .jpeg : .heif }

    static var saved: PhotoCodec {
        PhotoCodec(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.photoCodec) ?? "") ?? AppDefaults.photoCodec
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: SettingsKeys.photoCodec)
    }
}

/// 사진 해상도(MP): 12 → 24 → 48. 기기가 지원하는 값만
enum PhotoResolution {

    static let values = [12, 24, 48]

    /// 48MP는 LIVE를 끔 (LIVE 영상과 함께 쓸 수 있는지 확실하지 않아서)
    static let maxWithLivePhoto = 24

    /// 장치 사진 크기 → 12 / 24 / 48 중 가장 가까운 값
    static func megapixels(width: Int32, height: Int32) -> Int {
        let mp = Double(width) * Double(height) / 1_000_000
        return values.min { abs(Double($0) - mp) < abs(Double($1) - mp) } ?? 12
    }

    /// 장치 사진 크기 목록 → 고를 수 있는 MP (같은 MP는 하나로, 작은 것부터)
    static func available(in dimensions: [CMVideoDimensions]) -> [Int] {
        Array(Set(dimensions.map { megapixels(width: $0.width, height: $0.height) })).sorted()
    }

    static var saved: Int {
        let value = UserDefaults.standard.integer(forKey: SettingsKeys.photoResolution)
        return values.contains(value) ? value : AppDefaults.photoResolution
    }

    static func save(_ value: Int) {
        UserDefaults.standard.set(value, forKey: SettingsKeys.photoResolution)
    }
}
