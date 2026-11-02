//
//  CaptureModePicker.swift
//  포징
//
//  하단 가운데 `비디오 | 사진` 캡슐. 선택된 모드는 밝은 판 안에 노란 글씨 (docs/02_UI.md 7절).
//  탭하면 누른 쪽 모드. 누른 채 좌우로 밀거나 꾹 누르면 기본 카메라처럼 모드 줄로 펼쳐지고,
//  가운데 강조 캡슐은 그대로인 채 글자 줄이 손가락을 따라 미끄러진다 (캡슐 안 글자만 노란색).
//  손을 떼면 캡슐에 가장 가까운 모드로 자리 잡는다. 타임랩스 · 슬로 모션은 5단계에서 줄에 더한다.
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

    /// 펼친 줄이 손가락을 따라 움직인 거리 (선택된 모드가 가운데일 때 0)
    @State private var scrollOffset: CGFloat = 0
    /// 줄이 펼쳐진 순간의 손가락 이동 거리. 그 뒤로 움직인 만큼만 줄이 따라감
    @State private var expandTranslation: CGFloat?
    @State private var longPressTask: Task<Void, Never>?
    /// 손가락이 움직여 탭이 아닌 밀기가 됨
    @State private var hasMoved = false
    /// 캡슐 가운데 (화면 좌표). 탭한 쪽 모드를 고를 때 기준
    @State private var centerX: CGFloat = 0

    private let segmentSize = CGSize(width: 78, height: 40)
    /// 펼친 줄의 모드 사이 간격 (가운데끼리)
    private let stripSpacing: CGFloat = 110
    /// 펼친 줄 폭 (양 끝은 흐려짐)
    private let stripWidth: CGFloat = 320
    /// 이만큼 움직이면 탭이 아니라 밀기
    private let moveThreshold: CGFloat = 10
    /// 펼친 줄을 이만큼 밀면 옆 모드로
    private let swipeThreshold: CGFloat = 25

    var body: some View {
        ZStack {
            if isExpanded {
                strip
                    .transition(.opacity)
            } else {
                capsule
                    .transition(.opacity)
            }
        }
        .contentShape(.capsule)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midX } action: { centerX = $0 }
        // 탭 · 밀기 · 꾹 누르기를 한 제스처로 (버튼과 밀기 제스처가 서로 터치를 가져가지 않게)
        .gesture(touchGesture)
        .animation(.easeInOut(duration: 0.2), value: camera.captureMode)
        .animation(.easeOut(duration: 0.2), value: isExpanded)
        // 녹화가 시작되면 꾹 누르기 · 펼친 줄 정리
        .onChange(of: camera.captureActivity.isRecording) { _, isRecording in
            guard isRecording else { return }
            collapse()
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

    // MARK: - 모양

    /// 접힌 캡슐: 선택된 쪽에 강조 판
    private var capsule: some View {
        let selectedX = position(of: selectedIndex, spacing: segmentSize.width)
        return labels(spacing: segmentSize.width, color: .white)
            .background { highlight.offset(x: selectedX) }
            .overlay {
                labels(spacing: segmentSize.width, color: .cameraYellow)
                    .mask { Capsule().frame(width: segmentSize.width, height: segmentSize.height).offset(x: selectedX) }
            }
            .frame(width: segmentSize.width * CGFloat(Self.displayOrder.count), height: segmentSize.height)
            .padding(4)
            .glassEffect(.regular, in: .capsule)
    }

    /// 펼친 모드 줄: 강조 판은 가운데 고정, 글자 줄이 움직임
    private var strip: some View {
        let offset = clampedStripOffset
        return ZStack {
            highlight
            labels(spacing: stripSpacing, color: .white)
                .offset(x: offset)
            labels(spacing: stripSpacing, color: .cameraYellow)
                .offset(x: offset)
                .mask { Capsule().frame(width: segmentSize.width, height: segmentSize.height) }
        }
        .frame(width: stripWidth, height: segmentSize.height + 8)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                     .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
    }

    private var highlight: some View {
        Capsule()
            .fill(.white.opacity(0.18))
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
            .frame(width: segmentSize.width, height: segmentSize.height)
    }

    /// 모드 이름을 가운데 기준 간격대로 놓은 줄
    private func labels(spacing: CGFloat, color: Color) -> some View {
        ZStack {
            ForEach(Array(Self.displayOrder.enumerated()), id: \.element) { index, mode in
                Text(mode.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: segmentSize.width, height: segmentSize.height)
                    .offset(x: position(of: index, spacing: spacing))
            }
        }
    }

    // MARK: - 위치 계산

    private var selectedIndex: Int {
        Self.displayOrder.firstIndex(of: camera.captureMode) ?? 0
    }

    /// 줄 가운데 기준 index번째 모드의 x
    private func position(of index: Int, spacing: CGFloat) -> CGFloat {
        (CGFloat(index) - CGFloat(Self.displayOrder.count - 1) / 2) * spacing
    }

    /// 펼친 줄의 글자 줄 이동: 선택된 모드가 가운데 + 손가락 이동. 양 끝 모드까지만
    private var clampedStripOffset: CGFloat {
        let base = -position(of: selectedIndex, spacing: stripSpacing)
        let limit = position(of: Self.displayOrder.count - 1, spacing: stripSpacing)
        return min(max(base + scrollOffset, -limit), limit)
    }

    /// 지금 가운데 강조 판에 가장 가까운 모드
    private var centeredMode: CaptureMode {
        let order = Self.displayOrder
        let index = Int((CGFloat(order.count - 1) / 2 - clampedStripOffset / stripSpacing).rounded())
        return order[min(max(index, 0), order.count - 1)]
    }

    // MARK: - 제스처

    private var touchGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if longPressTask == nil, !isExpanded, !hasMoved {
                    startLongPress()
                }
                let translation = value.translation
                if !hasMoved, hypot(translation.width, translation.height) > moveThreshold {
                    // 어느 방향이든 움직이면 탭 · 꾹 누르기가 아님
                    hasMoved = true
                    cancelLongPress()
                    // 옆으로 밀 때만 바로 모드 줄로 펼쳐 손가락을 따라가게 함
                    if !isExpanded, abs(translation.width) > abs(translation.height) {
                        expand(at: translation.width)
                    }
                }
                if isExpanded {
                    let start = expandTranslation ?? value.translation.width
                    expandTranslation = start
                    scrollOffset = value.translation.width - start
                }
            }
            .onEnded { value in
                defer {
                    cancelLongPress()
                    hasMoved = false
                }
                guard !camera.captureActivity.isRecording else { return }
                if isExpanded {
                    var mode = centeredMode
                    // 반 칸을 못 넘겨도 조금 밀었으면 민 쪽 모드로
                    if mode == camera.captureMode, abs(scrollOffset) >= swipeThreshold {
                        mode = Self.mode(after: mode, swipe: scrollOffset < 0 ? .left : .right)
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        camera.captureMode = mode
                        scrollOffset = 0
                    }
                    collapse()
                } else if !hasMoved {
                    // 탭: 누른 쪽 모드
                    camera.captureMode = value.location.x < centerX ? Self.displayOrder[0] : Self.displayOrder[1]
                }
            }
    }

    private func startLongPress() {
        longPressTask = Task {
            try? await Task.sleep(for: .seconds(AppDefaults.longPressDuration))
            guard !Task.isCancelled, !hasMoved, !camera.captureActivity.isRecording else { return }
            expand(at: 0)
        }
    }

    private func expand(at translation: CGFloat) {
        cancelLongPress()
        expandTranslation = translation
        scrollOffset = 0
        isExpanded = true
    }

    private func collapse() {
        cancelLongPress()
        expandTranslation = nil
        scrollOffset = 0
        isExpanded = false
    }

    private func cancelLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }
}

#Preview {
    CaptureModePicker(camera: PreviewCameraModel(), isExpanded: .constant(true))
        .padding()
        .background(.black)
}
