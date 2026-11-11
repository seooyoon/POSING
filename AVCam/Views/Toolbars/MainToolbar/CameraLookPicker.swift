//
//  CameraLookPicker.swift
//  포징
//
//  셔터 왼쪽 카메라 버튼과 세로 카메라 목록 (docs/01_SPEC.md 7-1절, docs/02_UI.md 7절).
//  버튼 아래에 지금 카메라 이름. 버튼은 꾹 누르거나 위아래로 밀어 카메라를 바꾸고, 목록 칸은 꾹 눌러도 아무 동작 없다.
//

import SwiftUI

/// 지금 고른 카메라의 PNG가 그대로 버튼 모양, 아래에 이름.
/// 탭 = 목록 열고 닫기. 꾹 누르거나 위아래로 밀면 목록이 열리고, 손을 떼지 않고 위아래로 움직이면
/// 고른 칸이 손가락을 따라 바뀜 (모드 캡슐과 같은 방식). 움직인 뒤 손을 떼면 그 카메라로 바뀌고 목록이 닫힘,
/// 꾹 누르기만 하고 떼면 목록은 열린 채로 남음
struct CameraLookButton: View {

    let looks: CameraLookState
    @Binding var isListOpen: Bool
    /// 밀어서 고르는 중인 칸 (목록에서 이 칸만 불투명). 고르는 중이 아니면 nil
    @Binding var highlightedID: String?
    let onSelect: (CameraLookItem) -> Void

    @State private var isPressed = false
    @State private var longPressTask: Task<Void, Never>?
    /// 손가락이 움직여 탭이 아님
    @State private var hasMoved = false
    /// 고르기를 시작한 순간의 칸 · 손가락 위치
    @State private var dragStart: (index: Int, translation: CGFloat)?

    /// 이만큼 움직이면 탭이 아니라 밀기
    private let moveThreshold: CGFloat = 10

    var body: some View {
        Group {
            if let image = looks.selected?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: CameraLookList.cellSize, height: CameraLookList.cellSize)
        .scaleEffect(isPressed ? 0.9 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        // 이미지만으로는 어떤 카메라인지 모를 수 있어 아래에 이름 (버튼 자리 · 크기는 그대로)
        .overlay(alignment: .bottom) {
            Text(looks.selected?.name ?? "")
                .font(.system(size: AppDefaults.cameraNameFontSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
                .offset(y: AppDefaults.cameraNameGap + AppDefaults.cameraNameFontSize)
                .allowsHitTesting(false)
        }
        // 이미지와 아래 이름을 한 덩어리로 폰 방향대로 돌림 (이름은 늘 이미지 아래)
        .rotatesWithDevice()
        .contentShape(.rect)
        // 탭 · 꾹 누르기 · 밀기를 한 제스처로
        .gesture(touchGesture)
        .sensoryFeedback(.selection, trigger: highlightedID) { old, new in old != nil && new != nil }
        .accessibilityElement()
        .accessibilityLabel("카메라")
        .accessibilityValue(looks.selected?.name ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isListOpen.toggle() }
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private var touchGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !isPressed {
                    isPressed = true
                    startLongPress()
                }
                let translation = value.translation
                if !hasMoved, hypot(translation.width, translation.height) > moveThreshold {
                    hasMoved = true
                    cancelLongPress()
                    // 위아래로 밀면 바로 목록을 열고 고르기 시작 (옆으로 밀면 아무것도 안 함)
                    if dragStart == nil, abs(translation.height) > abs(translation.width) {
                        beginSelecting(at: translation.height)
                    }
                }
                if let start = dragStart {
                    // 위로 올리면 목록 위쪽 칸 (목록 1번이 맨 아래)
                    let steps = Int(((start.translation - translation.height) / CameraLookList.cellPitch).rounded())
                    let index = min(max(start.index + steps, 0), looks.items.count - 1)
                    if looks.items.indices.contains(index) {
                        highlightedID = looks.items[index].id
                    }
                }
            }
            .onEnded { _ in
                defer {
                    cancelLongPress()
                    isPressed = false
                    hasMoved = false
                    dragStart = nil
                    highlightedID = nil
                }
                if dragStart != nil {
                    // 꾹 누르고 움직이지 않고 떼면 목록만 열어 둠 (칸을 탭해서 고를 수 있게)
                    guard hasMoved else { return }
                    if let item = looks.items.first(where: { $0.id == highlightedID }) {
                        onSelect(item)
                    }
                    isListOpen = false
                } else if !hasMoved {
                    isListOpen.toggle()
                }
            }
    }

    private func startLongPress() {
        longPressTask = Task {
            try? await Task.sleep(for: .seconds(AppDefaults.longPressDuration))
            guard !Task.isCancelled, !hasMoved, dragStart == nil else { return }
            beginSelecting(at: 0)
        }
    }

    /// 목록을 열고 지금 카메라 칸에서 고르기 시작
    private func beginSelecting(at translation: CGFloat) {
        cancelLongPress()
        let index = looks.items.firstIndex { $0.id == looks.selected?.id } ?? 0
        dragStart = (index, translation)
        highlightedID = looks.items.indices.contains(index) ? looks.items[index].id : nil
        isListOpen = true
    }

    private func cancelLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    /// 보이스오버 위아래 쓸기: 옆 카메라로 바로 바꿈
    private func step(_ offset: Int) {
        guard let index = looks.items.firstIndex(where: { $0.id == looks.selected?.id }) else { return }
        let next = min(max(index + offset, 0), looks.items.count - 1)
        if next != index { onSelect(looks.items[next]) }
    }
}

/// 버튼 바로 위로 쌓이는 세로 목록. 목록 1번이 맨 아래
struct CameraLookList: View {

    static let cellSize: CGFloat = 52
    private static let spacing: CGFloat = 10
    /// 칸 아래 이름 자리 (카메라 버튼 이름과 같은 글자 · 간격)
    private static var nameHeight: CGFloat { AppDefaults.cameraNameGap + AppDefaults.cameraNameFontSize + 3 }
    /// 이름까지 포함한 칸 높이
    private static var cellHeight: CGFloat { cellSize + nameHeight }
    /// 칸 사이 거리 (가운데끼리). 버튼을 밀 때 이만큼 움직이면 한 칸
    static var cellPitch: CGFloat { cellHeight + spacing }
    private static let padding: CGFloat = 8
    /// 좌우 여백. 가로로 돌렸을 때 이미지 + 이름 덩어리(약 66pt) 양옆에도 여백이 남게 위아래보다 넉넉히
    private static let sidePadding: CGFloat = 13
    static let width = cellSize + sidePadding * 2

    let looks: CameraLookState
    /// 위쪽으로 펼칠 수 있는 높이. 넘치면 세로 스크롤
    let maxHeight: CGFloat
    /// 버튼을 밀어서 고르는 중인 칸. 있으면 이 칸이 선택된 모양
    var highlightedID: String?
    let onSelect: (CameraLookItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Self.spacing) {
                    ForEach(looks.items.reversed()) { item in
                        cell(item)
                            .id(item.id)
                    }
                }
                .padding(.vertical, Self.padding)
                .padding(.horizontal, Self.sidePadding)
            }
            // 밀어서 고르는 칸이 가려지지 않게 스크롤
            .onChange(of: highlightedID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) }
            }
        }
        .defaultScrollAnchor(.bottom)
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: Self.width, height: height)
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
    }

    var height: CGFloat {
        let count = CGFloat(looks.items.count)
        return min(maxHeight, count * Self.cellHeight + max(0, count - 1) * Self.spacing + Self.padding * 2)
    }

    /// 칸: 카메라 PNG + 아래 이름. 선택된 칸은 그대로, 나머지는 흐리게 (테두리 없음)
    private func cell(_ item: CameraLookItem) -> some View {
        let isSelected = (highlightedID ?? looks.selected?.id) == item.id
        return VStack(spacing: AppDefaults.cameraNameGap) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(width: Self.cellSize, height: Self.cellSize)
            Text(item.name)
                .font(.system(size: AppDefaults.cameraNameFontSize, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        // 이미지와 이름을 한 덩어리로 폰 방향대로 돌림 (가로로 돌아도 목록 폭 안에 들어감)
        .frame(width: Self.cellSize + 12)
        .rotatesWithDevice()
        .frame(width: Self.cellSize, height: Self.cellHeight, alignment: .top)
        .opacity(isSelected ? 1 : AppDefaults.cameraListUnselectedOpacity)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contentShape(.rect)
            .onTapGesture { onSelect(item) }
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {}
            .accessibilityElement()
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect(item) }
    }
}
