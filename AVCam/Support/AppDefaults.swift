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

    /// 꾹 누르기 인식 시간 (초). 햅틱 없음
    static let longPressDuration = 0.5
    /// 배율 버튼 길게 누르기 → 다이얼 (기본 카메라처럼 조금 더 빠름)
    static let zoomDialLongPressDuration = 0.4
    /// 카메라 목록은 바깥 탭 또는 카메라 버튼 다시 탭으로 닫힘
    static let closesCameraListOnOutsideTap = true
    /// 카메라 버튼 아래 이름 글자 크기 · 버튼과의 간격 (pt)
    static let cameraNameFontSize: CGFloat = 11
    static let cameraNameGap: CGFloat = 1
    /// 카메라 목록에서 선택되지 않은 칸 투명도 (선택된 칸은 그대로)
    static let cameraListUnselectedOpacity = 0.5

    // MARK: - 사진 형식

    /// 처음 형식 · 해상도 (기본 카메라 참고 화면 `JPEG 24`)
    static let photoCodec = PhotoCodec.jpeg
    static let photoResolution = 24

    // MARK: - 비디오 형식

    /// 처음 해상도 · 프레임률 (기본 카메라 빠른 설정 판의 점 표시 `4K` · `30`)
    static let videoResolution = VideoResolution.uhd
    static let videoFrameRate = 30
    /// 슬로 모션 처음 프레임률
    static let slowMotionFrameRate = 120
    /// 타임랩스: 이 간격(초)마다 한 장 골라 아래 프레임률로 재생 (0.5초 + 30fps = 15배속)
    static let timelapseInterval = 0.5
    static let timelapseFrameRate = 30
    /// 보정 미리보기(Metal)를 그리는 초당 횟수
    static let filteredPreviewFrameRate = 30
    /// 미리보기 바깥에 비치는 장면을 어둡게 덮는 정도 (0 = 그대로, 1 = 검정)
    static let outsidePreviewDimOpacity = 0.55
    /// 상단 오른쪽 묶음 아이콘 하나의 폭 (플래시 · LIVE · •••)
    static let topCapsuleIconWidth: CGFloat = 38
    /// 맨 위 줄(다이내믹 아일랜드 오른쪽) 스타일 아이콘 크기 · 화면 오른쪽 끝에서 아이콘 가운데까지 ·
    /// 상단 안전 영역 가운데보다 아래인 양 (기본 카메라 화면에서 잰 값)
    static let statusStyleIconSize: CGFloat = 15.5
    static let statusStyleIconTrailing: CGFloat = 70
    static let statusStyleIconBelowCenter: CGFloat = 1
    /// 폰을 이 각도(도)보다 많이 돌리면 아이콘을 가로로, 이 각도보다 적게 기울면 다시 세로로
    static let iconLandscapeAngle = 60.0
    static let iconPortraitAngle = 30.0
    /// 아이콘이 돌아가는 시간
    static let iconRotationDuration = 0.3
    /// 스타일 초기화 버튼이 사라질 때 화살표가 도는 각도(시계 반대 = 음수) · 걸리는 시간 (기본 카메라 녹화에서 잰 값)
    static let styleResetSpinDegrees: Double = -200
    static let styleResetSpinDuration: Double = 0.45
    /// 모드 선택 강조 판의 불투명도 (접힌 판 · 펼친 판 같이)
    static let modeHighlightOpacity = 0.08

    // MARK: - 노출 감도 (기본 카메라처럼 천천히)

    /// 초점 옆 해 아이콘을 이만큼(pt) 밀면 밝기 1 EV
    static let focusBiasPointsPerEV = 300.0
    /// 더보기 메뉴 노출 눈금을 이만큼(pt) 밀면 1/3 EV
    static let exposureRulerPointsPerStep = 45.0

    // MARK: - 장면 밝기

    /// 장면 밝기(EV100)가 이보다 낮으면 하단 조작부를 어두운 모양으로
    static let sceneDarkEV = 2.5
    /// 이보다 높아지면 평소 모양으로
    static let sceneBrightEV = 3.5

    // MARK: - 렌즈 청소 안내 · 꽃 버튼

    /// 렌즈 얼룩 감지 간격 (초). 짧을수록 닦은 뒤 빨리 사라지지만 배터리를 씀
    static let lensSmudgeDetectionInterval = 4.0
    /// 얼룩이 이 시간(초) 동안 계속 감지되어야 안내 (잘못 뜨는 것을 줄임)
    static let lensSmudgeConfirmDelay = 5.0
    /// 꽃을 끈 동안 렌즈 초점 위치(0 = 가장 가까움)가 이 값 이하면 가까움 → 꽃 버튼 보임
    static let macroCloseLensPosition: Float = 0.1
    /// 이 값 이상으로 멀어지면 꽃 버튼 숨김 (경계에서 깜빡이지 않게 두 값을 나눔)
    static let macroFarLensPosition: Float = 0.25
    /// 꽃 버튼 조건이 잠깐 풀려도 버튼을 유지하는 시간 (초). 접사 렌즈가 오가며 깜빡이지 않게
    static let macroButtonHoldDuration = 1.5
    /// 꽃 버튼이 나타나고 사라지는 시간 (초)
    static let macroButtonFadeDuration = 0.25

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
