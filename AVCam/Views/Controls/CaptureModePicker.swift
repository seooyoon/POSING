//
//  CaptureModePicker.swift
//  포징
//
//  하단 가운데 `비디오 | 사진` 캡슐. 선택된 모드는 밝은 판 안에 노란 글씨 (docs/02_UI.md 7절).
//  탭 · 좌우 밀기로 모드 전환. 꾹 누르면 기본 카메라처럼 모드 줄로 펼쳐지고, 밀어서 고른 뒤 떼면 선택.
//  타임랩스 · 슬로 모션은 5단계에서 줄에 더한다.
//

import SwiftUI

struct CaptureModePicker<CameraModel: Camera>: View {

    /// 화면에 보이는 순서. 기본 카메라처럼 사진이 오른쪽
    static var displayOrder: [CaptureMode] { [.video, .photo] }

    /// 미리보기를 좌우로 밀었을 때 바뀔 모드. 끝에서 더 밀면 그대로
    static func mode(after mode: CaptureMode, swipe direction: SwipeDirection) -> CaptureMode {
        let order = displayOrder
        guard let index = order.firstIndex(of: mode) else { return mode }
        // 오른쪽으로 밀면 왼쪽 모드, 왼쪽으로 밀면 오른쪽 모드
        let next = direction == .right ? index - 1 : index + 1
        return order.indices.contains(next) ? order[next] : mode
    }

    @State var camera: CameraModel
    /// 모드 줄이 펼쳐짐. 펼친 동안 썸네일 · 전환 버튼은 숨김 (BottomBar)
    @Binding var isExpanded: Bool

    /// 펼친 줄에서 손가락 아래 모드
    @State private var highlighted: CaptureMode?
    @State private var longPressTask: Task<Void, Never>?
    /// 손가락이 움직여 탭이 아닌 밀기가 됨
    @State private var hasMoved = false
    /// 캡슐 가운데 (화면 좌표). 터치 위치로 모드를 고를 때 기준
    @State private var centerX: CGFloat = 0

    private let segmentSize = CGSize(width: 78, height: 40)
    /// 펼친 줄의 모드 사이 간격 (가운데끼리)
    private let stripSpacing: CGFloat = 110
    /// 이만큼 움직이면 탭이 아님
    private let moveThreshold: CGFloat = 10
    /// 이만큼 좌우로 밀면 모드 전환
    private let swipeThreshold: CGFloat = 20

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(Self.displayOrder) { mode in
                    segment(mode, isSelected: camera.captureMode == mode)
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .opacity(isExpanded ? 0 : 1)

            if isExpanded {
                HStack(spacing: stripSpacing - segmentSize.width) {
                    ForEach(Self.displayOrder) { mode in
                        segment(mode, isSelected: highlighted == mode)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .contentShape(.capsule)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midX } action: { centerX = $0 }
        // 탭 · 밀기 · 꾹 누르기를 한 제스처로 (버튼과 밀기 제스처가 서로 터치를 가져가지 않게)
        .gesture(touchGesture)
        .animation(.easeInOut(duration: 0.2), value: camera.captureMode)
        .animation(.easeOut(duration: 0.2), value: isExpanded)
        .animation(.easeOut(duration: 0.15), value: highlighted)
        .sensoryFeedback(.selection, trigger: highlighted) { old, new in old != nil && new != nil }
        // 녹화가 시작되면 꾹 누르기 · 펼친 줄 정리
        .onChange(of: camera.captureActivity.isRecording) { _, isRecording in
            guard isRecording else { return }
            cancelLongPress()
            highlighted = nil
            isExpanded = false
        }
        .disabled(camera.captureActivity.isRecording)
        // 녹화 중에는 기본 카메라처럼 숨김
        .opacity(camera.captureActivity.isRecording ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("촬영 모드")
        .accessibilityValue(camera.captureMode.title)
        .accessibilityAdjustableAction { direction in
            camera.captureMode = Self.mode(after: camera.captureMode, swipe: direction == .increment ? .left : .right)
        }
    }

    private var touchGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if longPressTask == nil, !isExpanded {
                    startLongPress()
                }
                if !hasMoved, hypot(value.translation.width, value.translation.height) > moveThreshold {
                    hasMoved = true
                    // 펼치기 전에 움직이면 꾹 누르기가 아니라 밀기
                    if !isExpanded { cancelLongPress() }
                }
                if isExpanded {
                    highlighted = stripMode(at: value.location.x)
                }
            }
            .onEnded { value in
                defer {
                    cancelLongPress()
                    hasMoved = false
                }
                guard !camera.captureActivity.isRecording else { return }
                if isExpanded {
                    if let highlighted { camera.captureMode = highlighted }
                    isExpanded = false
                    highlighted = nil
                } else if hasMoved {
                    let translation = value.translation
                    guard abs(translation.width) >= swipeThreshold,
                          abs(translation.width) > abs(translation.height)
                    else { return }
                    let direction: SwipeDirection = translation.width < 0 ? .left : .right
                    camera.captureMode = Self.mode(after: camera.captureMode, swipe: direction)
                } else {
                    // 탭: 누른 쪽 모드
                    camera.captureMode = value.location.x < centerX ? Self.displayOrder[0] : Self.displayOrder[1]
                }
            }
    }

    private func startLongPress() {
        longPressTask = Task {
            try? await Task.sleep(for: .seconds(AppDefaults.longPressDuration))
            guard !Task.isCancelled, !hasMoved, !camera.captureActivity.isRecording else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            highlighted = camera.captureMode
            isExpanded = true
        }
    }

    private func cancelLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    /// 펼친 줄에서 손가락과 가장 가까운 모드
    private func stripMode(at x: CGFloat) -> CaptureMode {
        let order = Self.displayOrder
        let firstX = centerX - stripSpacing * CGFloat(order.count - 1) / 2
        let index = Int(((x - firstX) / stripSpacing).rounded())
        return order[min(max(index, 0), order.count - 1)]
    }

    private func segment(_ mode: CaptureMode, isSelected: Bool) -> some View {
        Text(mode.title)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isSelected ? Color.cameraYellow : .white)
            .frame(width: segmentSize.width, height: segmentSize.height)
            .background {
                if isSelected {
                    Capsule().fill(.white.opacity(0.18))
                }
            }
    }
}

#Preview {
    CaptureModePicker(camera: PreviewCameraModel(), isExpanded: .constant(false))
        .padding()
        .background(.black)
}
