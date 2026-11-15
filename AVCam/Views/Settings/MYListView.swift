//
//  MYListView.swift
//  포징
//
//  설정 > MY 패키지 하나: 직접 추가한 사진 추가 · 이름 붙이기 · 끌어서 순서 변경 · 삭제 (docs/01_SPEC.md 6절).
//  맨 위 = 카메라 화면 패키지 안 맨 왼쪽. 앱에 넣어 둔 사진은 그 뒤에 고정 순서로 보이고 여기서는 고치지 않음.
//

import SwiftUI

struct MYListView: View {

    @Bindable var layers: LayerState
    let packageID: String

    @State private var editMode = EditMode.inactive
    @State private var pickingPackageID: String?

    private var package: MYPackage? { layers.myPackage(packageID) }
    private var items: [LayerItem] { package?.addedItems ?? [] }

    /// 끌어서 정렬은 편집을 눌렀을 때만
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard editMode.isEditing else { return nil }
        return { source, destination in
            layers.moveMY(inPackage: packageID, from: source, to: destination)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    pickingPackageID = packageID
                } label: {
                    Label("사진 추가", systemImage: "plus")
                }
            } footer: {
                Text("카메라 화면에서 패키지 대표 이미지를 꾹 눌러도 추가할 수 있습니다.")
            }

            Section {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        SettingsThumbnailRow(image: item.thumbnail)
                        MYNameField(name: item.name) { layers.renameMY(item.id, inPackage: packageID, to: $0) }
                    }
                }
                .onMove(perform: moveAction)
                .onDelete { layers.deleteMY(inPackage: packageID, at: $0) }
            } header: {
                Text("추가한 사진")
            } footer: {
                if items.isEmpty {
                    Text("추가한 사진이 없습니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("MY \(package?.name ?? "")")
        .toolbar {
            EditToggleButton(editMode: $editMode)
        }
        .environment(\.editMode, $editMode)
        // 카메라 화면에서 대표 이미지 꾹 누르기와 같은 동작
        .myPhotoPicker(packageID: $pickingPackageID, layers: layers)
    }
}

/// MY 사진 이름 입력칸. 10자를 넘는 입력은 즉시 되돌려 칸에도 보이지 않음
private struct MYNameField: View {

    let onChange: (String) -> Void
    @State private var text: String

    init(name: String, onChange: @escaping (String) -> Void) {
        self.onChange = onChange
        _text = State(initialValue: name)
    }

    var body: some View {
        TextField("이름", text: $text)
            .submitLabel(.done)
            .onChange(of: text) { oldValue, newValue in
                // 넘치는 입력(가운데 끼워 넣기 · 붙여넣기 포함)은 받지 않고 이전 이름으로
                guard newValue.count <= MYLibrary.maxNameLength else {
                    text = oldValue
                    return
                }
                onChange(newValue)
            }
    }
}
