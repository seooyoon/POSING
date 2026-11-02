//
//  MYListView.swift
//  포징
//
//  설정 > MY 목록: 사진 추가 · 이름 붙이기 · 끌어서 순서 변경 · 삭제 (docs/01_SPEC.md 6절).
//  추가한 사진은 맨 위 = 카메라 화면 목록 맨 왼쪽.
//

import SwiftUI

struct MYListView: View {

    @Bindable var layers: LayerState

    @State private var editMode = EditMode.inactive

    /// 끌어서 정렬은 편집을 눌렀을 때만
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard editMode.isEditing else { return nil }
        return { source, destination in
            layers.moveMY(from: source, to: destination)
        }
    }
    @State private var isPicking = false

    var body: some View {
        List {
            Section {
                Button {
                    isPicking = true
                } label: {
                    Label("사진 추가", systemImage: "plus")
                }
            }

            Section {
                ForEach(layers.my.items) { item in
                    HStack(spacing: 12) {
                        SettingsThumbnailRow(image: item.thumbnail)
                        TextField("이름", text: nameBinding(for: item))
                            .submitLabel(.done)
                    }
                }
                .onMove(perform: moveAction)
                .onDelete(perform: layers.deleteMY)
            } footer: {
                if layers.my.items.isEmpty {
                    Text("추가한 사진이 없습니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("MY 목록")
        .toolbar {
            EditToggleButton(editMode: $editMode)
        }
        .environment(\.editMode, $editMode)
        // 카메라 화면에서 MY 꾹 누르기와 같은 동작
        .myPhotoPicker(isPresented: $isPicking, layers: layers)
    }

    /// 입력하는 동안 10자를 넘으면 잘라서 저장
    private func nameBinding(for item: LayerItem) -> Binding<String> {
        Binding {
            layers.my.items.first { $0.id == item.id }?.name ?? ""
        } set: { name in
            layers.renameMY(item.id, to: name)
        }
    }
}
