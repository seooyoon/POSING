//
//  AppDefaults.swift
//  포징
//
//  아직 확정되지 않은 결정의 임시 기본값 (CLAUDE.md 6절).
//  결정이 바뀌면 이 파일만 고치고, CLAUDE.md 6절도 같이 고친다.
//

import Foundation

enum AppDefaults {

    // MARK: - 레이어 투명도

    /// 포즈 테두리 투명도. 칸을 새로 고를 때마다 이 값에서 시작
    static let poseOpacity = 1.0
    /// MY 사진 투명도. 칸을 새로 고를 때마다 이 값에서 시작
    static let myOpacity = 0.35
    /// 투명도 조절 범위 (5%~100%)
    static let opacityRange = 0.05...1.0
    /// 투명도 조절 단위 (5%)
    static let opacityStep = 0.05

    // MARK: - MY 사진 추가

    /// 사진 여러 장 선택 허용. 선택 순서대로 맨 왼쪽에 쌓고 1번을 바로 적용
    static let allowsMultipleMYSelection = true

    // MARK: - 버튼 동작

    /// 꾹 누르기 인식 시간 (초). 인식되는 순간 햅틱
    static let longPressDuration = 0.5
    /// 카메라 목록은 바깥 탭 또는 카메라 버튼 다시 탭으로 닫힘
    static let closesCameraListOnOutsideTap = true

    // MARK: - 화면 표시

    /// 3x3 격자 기본값
    static let isGridEnabled = true
    /// 중심점 기본값
    static let isCenterMarkEnabled = false

    // MARK: - 색감 · LIVE

    /// 카메라 색감과 스타일을 같이 쓰면 둘 다 적용 (카메라 색감 먼저 → 스타일)
    static let appliesCameraLookBeforeStyle = true
    /// 표준이 아닌 스타일일 때 LIVE 자동 끔
    static let turnsOffLiveForNonStandardStyle = true
    /// 기본이 아닌 카메라일 때 LIVE 자동 끔 (카메라 색감은 사진에만 적용)
    static let turnsOffLiveForNonDefaultCamera = true
    /// 비율이 4:3이 아닐 때 LIVE 자동 끔
    static let turnsOffLiveForNonFourThreeRatio = true
}
