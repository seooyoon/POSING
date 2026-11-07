//
//  CameraOrderView.swift
//  포징
//
//  설정 > 카메라 목록: 탭해서 시작 카메라를 고르고, 편집에서 끌어서 순서를 바꾼다. 추가 · 삭제 없음 (docs/01_SPEC.md 6절).
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
            Section {
                ForEach(looks.items) { item in
                    row(item)
                }
                .onMove(perform: moveAction)
            } footer: {
                Text("체크한 카메라로 앱이 시작됩니다. 카메라 화면에서 바꾼 카메라는 앱을 다시 켜면 이 카메라로 돌아갑니다.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("카메라 목록")
        .toolbar {
            EditToggleButton(editMode: $editMode)
        }
        .environment(\.editMode, $editMode)
    }

    /// 탭하면 시작 카메라로 고정 (편집 중에는 순서만)
    private func row(_ item: CameraLookItem) -> some View {
        let isStart = looks.startItem?.id == item.id
        return Button {
            looks.setStart(item)
        } label: {
            HStack {
                SettingsThumbnailRow(image: item.image, title: item.name, fillsFrame: false)
                Spacer()
                if isStart {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(editMode.isEditing)
        .accessibilityAddTraits(isStart ? .isSelected : [])
    }
}
