//
//  TopBar.swift
//  포징
//
//  상단 바: 형식 버튼 · 설정 · 초기화 · MY · [플래시 · LIVE · •••] (docs/02_UI.md 2절)
//

import SwiftUI

struct TopBar<CameraModel: Camera>: View {

    @State var camera: CameraModel
    let layers: LayerState
    @Binding var isShowingMoreMenu: Bool
    /// 열린 빠른 설정 판 (형식 버튼 · 오른쪽 묶음 꾹 누르기)
    @Binding var quickSettings: QuickSettingsKind?

    /// 초기화 탭 햅틱 트리거
    @State private var resetCount = 0

    var body: some View {
        HStack(spacing: 8) {
            if camera.captureActivity.isRecording {
                // 녹화 중에는 기본 카메라처럼 녹화 시간만 보임
                Spacer()
                RecordingTimeView(time: camera.captureActivity.currentTime)
                Spacer()
            } else {
                // 타임랩스에는 고를 형식이 없음
                if camera.captureMode != .timelapse {
                    FormatButton(camera: camera, quickSettings: $quickSettings)
                }
                // 설정 · 초기화 · 포즈(MY 기능): 따로 떨어진 버튼 3개 (docs/01_SPEC.md 2절)
                PosingButton(title: "설정") {
                    // 아래에서 올라오는 효과 없이 바로 화면을 채움
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { layers.isShowingSettings = true }
                }
                PosingButton(title: "초기화") {
                    layers.reset()
                    resetCount += 1
                }
                .sensoryFeedback(.impact(weight: .light), trigger: resetCount)
                PosingButton(title: "포즈",
                             isActive: layers.openPanel == .my || layers.my.isSelected,
                             onHold: { layers.isPeekingMY = $0 }) {
                    layers.togglePanel(.my)
                }
                Spacer(minLength: 0)
                TopControlsCapsule(camera: camera, isShowingMoreMenu: $isShowingMoreMenu, quickSettings: $quickSettings)
            }
        }
        .padding(.horizontal, CameraLayout.sideInset)
        .animation(.easeInOut(duration: 0.25), value: camera.captureMode)
        // 카메라 컨트롤 버튼을 밀고 있는 동안은 숨김
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
        .hidden(until: camera.status == .running)
    }
}

/// 설정 · 초기화 · MY 버튼. 형식 버튼과 같은 높이 · 배경 · 글자 크기, 폭은 글자에 맞춤
struct PosingButton: View {

    let title: String
    /// 패널이 열려 있거나 사진이 적용되어 있으면 노란 글자
    var isActive = false
    /// 꾹 누른 뒤 손을 뗄 때까지 true (MY 원본 보기). 없으면 꾹 눌러도 아무 반응 없음
    var onHold: ((Bool) -> Void)?
    let action: () -> Void

    var body: some View {
        Text(title)
            .foregroundStyle(isActive ? Color.cameraYellow : .white)
            .topBarCapsule(horizontalPadding: 10)
            .contentShape(.capsule)
            .onTapGesture(perform: action)
            // 꾹 누르기는 항상 받아서, 꾹 눌렀다 떼도 탭으로 처리되지 않게 함
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                onHold?(true)
            } onPressingChanged: { isPressing in
                if !isPressing { onHold?(false) }
            }
            // 누르는 중에 버튼이 사라져도(녹화 시작 등) 원본 보기가 남지 않게
            .onDisappear { onHold?(false) }
    }
}

#Preview {
    TopBar(camera: PreviewCameraModel(status: .running), layers: LayerState(),
           isShowingMoreMenu: .constant(false), quickSettings: .constant(nil))
        .background(.gray)
}
