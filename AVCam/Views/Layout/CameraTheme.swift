//
//  CameraTheme.swift
//  포징
//
//  기본 카메라와 맞춘 색 · 버튼 모양.
//

import SwiftUI

extension Color {
    /// 기본 카메라의 선택값 노란색 (#FFD60A)
    static let cameraYellow = Color(red: 1.0, green: 214 / 255, blue: 10 / 255)
}

extension CaptureMode {
    /// 하단 캡슐에 보이는 모드 이름
    var title: String {
        switch self {
        case .photo: "사진"
        case .video: "비디오"
        }
    }
}

/// 상단 바 캡슐 높이 (형식 버튼 · 초기화 · 포즈 · MY · 오른쪽 묶음 공통)
let topBarControlHeight: CGFloat = 35

/// 상단 바 글자 크기. 기본 카메라(17pt)보다 조금 작게 해서 버튼 3개가 더 들어가게 함
let topBarFontSize: CGFloat = 15

/// 하단 줄 원형 버튼 크기 (썸네일 · 전환 버튼)
let bottomRowButtonSize: CGFloat = 48

extension View {
    /// 상단 바 캡슐 모양. 반투명 유리 판 위에 흰 글자
    func topBarCapsule(horizontalPadding: CGFloat = 12) -> some View {
        font(.system(size: topBarFontSize))
            .foregroundStyle(.white)
            // 글자가 "…"로 잘리지 않게 폭을 글자에 고정
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, horizontalPadding)
            .frame(height: topBarControlHeight)
            .glassEffect(.regular, in: .capsule)
    }
}
