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
    /// 즐겨찾기한 카메라 id 목록 (카메라 버튼 · 목록 · 설정에서 두 번 빠르게 탭)
    static let favoriteCameras = "favoriteCameras"
    /// 앱을 켤 때 쓸 카메라 id (설정 > 카메라 목록)
    static let startCamera = "startCamera"
    /// 플래시 (자동 · 켬 · 끔)
    static let flashMode = "flashMode"
    /// 타이머 초 (0 = 끔)
    static let timerDuration = "timerDuration"
    /// 사진 형식 (JPEG · RAW)
    static let photoCodec = "photoCodec"
    /// 사진 해상도 MP (12 · 24 · 48)
    static let photoResolution = "photoResolution"
    /// 비디오 해상도 (HD · 4K)
    static let videoResolution = "videoResolution"
    /// 비디오 프레임률 (24 · 30 · 60)
    static let videoFrameRate = "videoFrameRate"
    /// 슬로 모션 프레임률 (120 · 240)
    static let slowMotionFrameRate = "slowMotionFrameRate"
}
