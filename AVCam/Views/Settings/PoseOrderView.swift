//
//  PoseOrderView.swift
//  포징
//
//  설정 > 포즈 목록: 끌어서 순서만 바꾼다. 추가 · 삭제 없음 (docs/01_SPEC.md 6절).
//

import SwiftUI

struct PoseOrderView: View {

    let layers: LayerState

    @State private var editMode = EditMode.inactive

    var body: some View {
        List {
            ForEach(Array(layers.pose.items.enumerated()), id: \.element.id) { index, item in
                SettingsThumbnailRow(image: item.thumbnail, title: "\(index + 1)")
            }
            .onMove(perform: layers.movePoses)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("포즈 목록")
        .toolbar {
            EditToggleButton(editMode: $editMode)
        }
        .environment(\.editMode, $editMode)
    }
}

/// 설정 목록 한 줄: 썸네일 + 글자
struct SettingsThumbnailRow: View {

    let image: UIImage
    var title: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 8))
            if let title {
                Text(title)
            }
        }
    }
}

/// 오른쪽 위 편집 / 완료 버튼
struct EditToggleButton: View {

    @Binding var editMode: EditMode

    var body: some View {
        Button(editMode.isEditing ? "완료" : "편집") {
            withAnimation {
                editMode = editMode.isEditing ? .inactive : .active
            }
        }
    }
}
