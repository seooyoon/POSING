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
    /// 설정에서 바꾼 카메라 순서 (카메라 id 목록)
    static let cameraOrder = "cameraOrder"
    /// 지금 고른 카메라 id
    static let selectedCamera = "selectedCamera"
    /// 고른 스타일 (PhotoStyle 원시값)
    static let photoStyle = "photoStyle"
    /// 스타일마다 바꾼 톤 · 색상 · 팔레트 (JSON)
    static let styleValues = "styleValues"
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
