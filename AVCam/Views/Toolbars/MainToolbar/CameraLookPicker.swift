//
//  CameraLookPicker.swift
//  포징
//
//  셔터 왼쪽 카메라 버튼과 세로 카메라 목록 (docs/01_SPEC.md 7-1절, docs/02_UI.md 7절).
//  버튼 · 목록 칸 모두 꾹 눌러도 아무 동작 없다.
//

import SwiftUI

/// 지금 고른 카메라의 PNG가 그대로 버튼 모양
struct CameraLookButton: View {

    let looks: CameraLookState
    @Binding var isListOpen: Bool

    @State private var isPressed = false

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
        .contentShape(.rect)
        .onTapGesture { isListOpen.toggle() }
        // 꾹 누르면 탭으로 처리되지 않고 그냥 끝남
        .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration, perform: {}, onPressingChanged: { isPressed = $0 })
        .accessibilityElement()
        .accessibilityLabel("카메라")
        .accessibilityValue(looks.selected?.name ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isListOpen.toggle() }
    }
}

/// 버튼 바로 위로 쌓이는 세로 목록. 목록 1번이 맨 아래
struct CameraLookList: View {

    static let cellSize: CGFloat = 52
    private static let spacing: CGFloat = 10
    private static let padding: CGFloat = 8
    static let width = cellSize + padding * 2

    let looks: CameraLookState
    /// 위쪽으로 펼칠 수 있는 높이. 넘치면 세로 스크롤
    let maxHeight: CGFloat
    let onSelect: (CameraLookItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Self.spacing) {
                ForEach(looks.items.reversed()) { item in
                    cell(item)
                }
            }
            .padding(Self.padding)
        }
        .defaultScrollAnchor(.bottom)
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: Self.width, height: height)
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
    }

    var height: CGFloat {
        let count = CGFloat(looks.items.count)
        return min(maxHeight, count * Self.cellSize + max(0, count - 1) * Self.spacing + Self.padding * 2)
    }

    private func cell(_ item: CameraLookItem) -> some View {
        let isSelected = looks.selected?.id == item.id
        return Image(uiImage: item.image)
            .resizable()
            .scaledToFit()
            .frame(width: Self.cellSize, height: Self.cellSize)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.cameraYellow, lineWidth: isSelected ? 2 : 0)
            }
            .contentShape(.rect(cornerRadius: 10))
            .onTapGesture { onSelect(item) }
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {}
            .accessibilityElement()
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect(item) }
    }
}
