//
//  MoreMenu.swift
//  포징
//
//  ••• 더보기 메뉴: 화면 아래에서 올라오는 둥근 판, 원형 버튼 3열 (docs/01_SPEC.md 8절, docs/02_UI.md 8절).
//  1줄 플래시 · LIVE · 타이머 / 2줄 노출 · 스타일 · 비율. 야간 모드는 만들 수 없어서 뺐다.
//  판 바깥을 탭하거나 판을 아래로 밀면 닫힌다.
//

import SwiftUI

struct MoreMenu<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var isPresented: Bool

    @State private var isShowingExposure = false
    @State private var dragOffset: CGFloat = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    var body: some View {
        VStack(spacing: 24) {
            if isShowingExposure {
                ExposureRuler(value: $camera.exposureCompensation)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(items, id: \.self) { item in
                    button(for: item)
                }
            }
        }
        .padding(.top, 30)
        .padding(.bottom, 34)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 48, style: .continuous)
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(.black.opacity(0.35)))
                .overlay(shape.stroke(.white.opacity(0.2), lineWidth: 0.5))
        }
        .offset(y: max(dragOffset, 0))
        .gesture(closeDrag)
        .animation(.easeOut(duration: 0.2), value: isShowingExposure)
    }

    /// 비디오 모드에는 LIVE · 타이머 · 스타일 · 비율이 없음. 전면 카메라는 비디오 조명이 없음
    private var items: [MoreMenuItem] {
        switch camera.captureMode {
        case .photo:
            return MoreMenuItem.allCases
        case .video:
            return camera.zoom.isFrontCamera ? [.exposure] : [.flash, .exposure]
        }
    }

    @ViewBuilder
    private func button(for item: MoreMenuItem) -> some View {
        switch item {
        case .flash:
            MoreMenuButton(title: "플래시", isActive: camera.flashMode == .on) {
                Image(systemName: camera.flashMode.symbolName)
            } action: {
                camera.flashMode = camera.flashMode.next
            }
        case .live:
            // 비율이 4:3이 아니거나 48MP면 LIVE 꺼짐 표시, 누를 수 없음
            MoreMenuButton(title: "LIVE", isActive: camera.isLivePhotoActive) {
                Image(systemName: camera.isLivePhotoActive ? "livephoto" : "livephoto.slash")
            } action: {
                camera.isLivePhotoEnabled.toggle()
            }
            .disabled(!camera.isLivePhotoAvailable)
        case .timer:
            MoreMenuButton(title: camera.timerDuration.title, isActive: camera.timerDuration != .off) {
                Image(systemName: "timer")
            } action: {
                camera.timerDuration = camera.timerDuration.next
            }
        case .exposure:
            let value = camera.exposureCompensation
            MoreMenuButton(title: abs(value) < 0.05 ? "노출" : ExposureCompensation.label(value),
                           isActive: isShowingExposure || abs(value) >= 0.05) {
                Image(systemName: "plusminus")
            } action: {
                isShowingExposure.toggle()
            }
        case .style:
            // 스타일 화면은 6단계에서 연결
            MoreMenuButton(title: "스타일") {
                Image(systemName: "circle.grid.3x3")
            } action: {}
        case .ratio:
            MoreMenuButton(title: "비율", isActive: camera.photoAspect != .fourThree) {
                RatioIcon(text: camera.photoAspect.label)
            } action: {
                camera.photoAspect = camera.photoAspect.next
            }
        }
    }

    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 60 {
                    isPresented = false
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                }
            }
    }
}

enum MoreMenuItem: CaseIterable {
    case flash, live, timer, exposure, style, ratio
}

/// 원형 버튼 + 아래 이름. 켜진 값은 노란색
private struct MoreMenuButton<Icon: View>: View {

    let title: String
    var isActive = false
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                icon
                    .font(.system(size: 24))
                    .foregroundStyle(isActive ? Color.cameraYellow : .white)
                    .frame(width: 68, height: 68)
                    .background(.white.opacity(0.12), in: .circle)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: title)
    }
}

/// 비율 버튼: 모서리 괄호 안에 현재 비율 글자
struct RatioIcon: View {

    let text: String

    var body: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 30, weight: .light))
            .overlay {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .minimumScaleFactor(0.6)
            }
    }
}

#Preview {
    MoreMenu(camera: PreviewCameraModel(status: .running), isPresented: .constant(true))
        .padding(8)
        .background(.gray)
}
