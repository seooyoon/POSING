//
//  MYListView.swift
//  포징
//
//  설정 > MY 목록: 사진 추가 · 끌어서 순서 변경 · 삭제 (docs/01_SPEC.md 6절).
//  추가한 사진은 맨 위 = 카메라 화면 목록 맨 왼쪽.
//

import SwiftUI

struct MYListView: View {

    @Bindable var layers: LayerState

    @State private var editMode = EditMode.inactive
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
                    SettingsThumbnailRow(image: item.thumbnail)
                }
                .onMove(perform: layers.moveMY)
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
}
