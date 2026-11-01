//
//  SettingsKeys.swift
//  포징
//
//  설정 화면 값을 앱에 저장할 때 쓰는 키 (UserDefaults).
//

import Foundation

enum SettingsKeys {
    /// 3x3 격자 켜기 (기본값 AppDefaults.isGridEnabled)
    static let isGridEnabled = "isGridEnabled"
    /// 중심점 켜기 (기본값 AppDefaults.isCenterMarkEnabled)
    static let isCenterMarkEnabled = "isCenterMarkEnabled"
    /// 설정에서 바꾼 포즈 순서 (포즈 id 목록)
    static let poseOrder = "poseOrder"
    /// 플래시 (자동 · 켬 · 끔)
    static let flashMode = "flashMode"
    /// 타이머 초 (0 = 끔)
    static let timerDuration = "timerDuration"
    /// 사진 비율 (4:3 · 16:9 · 1:1)
    static let photoAspect = "photoAspect"
    /// 사진 형식 (HEIF · JPEG)
    static let photoCodec = "photoCodec"
    /// 사진 해상도 MP (12 · 24 · 48)
    static let photoResolution = "photoResolution"
}
