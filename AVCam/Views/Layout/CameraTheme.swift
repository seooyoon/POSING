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
        case .slowMotion: "슬로 모션"
        case .timelapse: "타임랩스"
        }
    }
}

/// 상단 바 캡슐 높이 (형식 버튼 · 초기화 · 포즈 · MY · 오른쪽 묶음 공통)
let topBarControlHeight: CGFloat = 35

/// 상단 바 글자 크기. 기본 카메라(17pt)보다 조금 작게 해서 버튼 3개가 더 들어가게 함
let topBarFontSize: CGFloat = 15

/// 하단 줄 원형 버튼 크기 (썸네일 · 전환 버튼)
let bottomRowButtonSize: CGFloat = 48

extension Font {
    /// 기본 카메라 숫자 글꼴: 0에 빗금
    static func cameraDigits(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let slashedZero: [UIFontDescriptor.FeatureKey: Int] = [.type: 14, .selector: 4]
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: [slashedZero]])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}

/// 유리 판이 눌린 자리에서 부풀어 나오고 되돌아 들어가는 전환 (기본 카메라에서 잰 움직임)
struct GlassPopTransition: Transition {
    let anchor: UnitPoint
    var scaleX: CGFloat = 0.28
    var scaleY: CGFloat = 0.28

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(x: phase.isIdentity ? 1 : scaleX, y: phase.isIdentity ? 1 : scaleY, anchor: anchor)
            .blur(radius: phase.isIdentity ? 0 : 8)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

extension AnyTransition {
    /// 열릴 때는 살짝 튕기며, 닫힐 때는 빠르게
    static func glassPop(_ transition: GlassPopTransition) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition(transition).animation(.spring(duration: 0.34, bounce: 0.22)),
            removal: AnyTransition(transition).animation(.easeIn(duration: 0.18))
        )
    }
}

extension View {
    /// 하단 유리: 틴트 없이 뒤에 비치는 것만 보임. 바깥이 검정이면 기본 카메라처럼 어두운 판,
    /// 장면이 비치면 그 색이 비침
    func bottomGlass(in shape: some Shape) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// 상단 바 캡슐 모양. 반투명 유리 판 위에 흰 글자
    func topBarCapsule(horizontalPadding: CGFloat = 12) -> some View {
        font(.system(size: topBarFontSize))
            .foregroundStyle(.white)
            // 글자가 "…"로 잘리지 않게 폭을 글자에 고정
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, horizontalPadding)
            .frame(height: topBarControlHeight)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// 폰 방향에 맞춰 아이콘 · 글자를 돌릴 각도 (CameraView가 LevelModel 값으로 넣어 줌)
extension EnvironmentValues {
    @Entry var iconAngle: Double = 0
}

private struct RotatesWithDevice: ViewModifier {
    @Environment(\.iconAngle) private var angle

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .animation(.easeInOut(duration: AppDefaults.iconRotationDuration), value: angle)
    }
}

extension View {
    /// 화면은 세로로 두고 이 아이콘 · 글자만 폰 방향에 맞게 돌림 (기본 카메라와 같음)
    func rotatesWithDevice() -> some View {
        modifier(RotatesWithDevice())
    }
}
