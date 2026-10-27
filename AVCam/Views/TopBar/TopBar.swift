//
//  TopBar.swift
//  포징
//
//  상단 바: 형식 버튼 · 초기화 · 포즈 · MY · [플래시 · LIVE · •••] (docs/02_UI.md 2절)
//

import SwiftUI

struct TopBar<CameraModel: Camera>: View {

    @State var camera: CameraModel
    let layers: LayerState

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
                FormatButton(captureMode: camera.captureMode)
                // 초기화 · 포즈 · MY: 따로 떨어진 버튼 3개 (docs/01_SPEC.md 2절)
                PosingButton(title: "초기화", onLongPress: {
                    // 설정 화면은 #8에서 연결
                }) {
                    layers.reset()
                    resetCount += 1
                }
                .sensoryFeedback(.impact(weight: .light), trigger: resetCount)
                PosingButton(title: "포즈",
                             isActive: layers.openPanel == .pose,
                             showsDot: layers.pose.isSelected) {
                    layers.togglePanel(.pose)
                }
                PosingButton(title: "MY",
                             isActive: layers.openPanel == .my,
                             showsDot: layers.my.isSelected,
                             onLongPress: {
                    layers.isPickingMY = true
                }) {
                    layers.togglePanel(.my)
                }
                Spacer(minLength: 0)
                TopControlsCapsule(camera: camera)
            }
        }
        .padding(.horizontal, CameraLayout.sideInset)
        // 카메라 컨트롤 버튼을 밀고 있는 동안은 숨김
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
        .hidden(until: camera.status == .running)
    }
}

/// 초기화 · 포즈 · MY 버튼. 형식 버튼과 같은 높이 · 배경 · 글자 크기, 폭은 글자에 맞춤
struct PosingButton: View {

    let title: String
    /// 열려 있는 패널의 버튼은 노란색
    var isActive = false
    /// 레이어가 선택되어 있으면 글자 아래 작은 점
    var showsDot = false
    /// 꾹 누르기 동작. 없으면 꾹 눌러도 아무 반응 없음 (포즈)
    var onLongPress: (() -> Void)?
    let action: () -> Void

    @State private var longPressCount = 0
    @State private var isPopped = false

    var body: some View {
        Text(title)
            .foregroundStyle(isActive ? Color.cameraYellow : .white)
            .overlay(alignment: .bottom) {
                if showsDot {
                    Circle()
                        .fill(isActive ? Color.cameraYellow : .white)
                        .frame(width: 4, height: 4)
                        .offset(y: 7)
                }
            }
            .topBarCapsule(horizontalPadding: 10)
            .scaleEffect(isPopped ? 1.12 : 1)
            .contentShape(.capsule)
            .onTapGesture(perform: action)
            // 꾹 누르기는 항상 받아서, 포즈는 꾹 눌렀다 떼도 탭으로 처리되지 않게 함
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                guard let onLongPress else { return }
                longPressCount += 1
                popAnimation()
                onLongPress()
            }
            .sensoryFeedback(.impact, trigger: longPressCount)
    }

    /// 꾹 누르기 인식 시 살짝 커졌다 돌아옴
    private func popAnimation() {
        withAnimation(.easeOut(duration: 0.12)) {
            isPopped = true
        } completion: {
            withAnimation(.easeIn(duration: 0.12)) {
                isPopped = false
            }
        }
    }
}

#Preview {
    TopBar(camera: PreviewCameraModel(status: .running), layers: LayerState())
        .background(.gray)
}
