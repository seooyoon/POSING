//
//  CameraOrderView.swift
//  포징
//
//  설정 > 카메라 목록: 끌어서 순서만 바꾼다. 추가 · 삭제 없음 (docs/01_SPEC.md 6절).
//

import SwiftUI

struct CameraOrderView: View {

    let looks: CameraLookState

    @State private var editMode = EditMode.inactive

    /// 끌어서 정렬은 편집을 눌렀을 때만
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard editMode.isEditing else { return nil }
        return { source, destination in
            looks.move(from: source, to: destination)
        }
    }

    var body: some View {
        List {
            ForEach(looks.items) { item in
                SettingsThumbnailRow(image: item.image, title: item.name, fillsFrame: false)
            }
            .onMove(perform: moveAction)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("카메라 목록")
        .toolbar {
            EditToggleButton(editMode: $editMode)
        }
        .environment(\.editMode, $editMode)
    }
}
