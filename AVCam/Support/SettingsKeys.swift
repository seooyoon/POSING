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
}
