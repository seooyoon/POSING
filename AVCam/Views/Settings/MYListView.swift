//
//  MYListView.swift
//  포징
//
//  설정 > MY 패키지 하나: 넣어 둔 사진 + 추가한 사진 전체. 추가 · 이름 붙이기 · 끌어서 순서 변경 · 삭제 (docs/01_SPEC.md 6절).
//  맨 위 = 카메라 화면 패키지 안 맨 왼쪽. 넣어 둔 사진은 지우면 숨겨지고 되돌릴 수 있음.
//

import SwiftUI

struct MYListView: View {

    @Bindable var layers: LayerState
    let packageID: String

    @State private var editMode = EditMode.inactive
    @State private var pickingPackageID: String?

    private var package: MYPackage? { layers.myPackage(packageID) }
    private var items: [LayerItem] { package?.items ?? [] }
    /// 지운 넣어 둔 사진 수 (목록이 바뀔 때마다 다시 셈)
    private var hiddenCount: Int { package?.library.hiddenCount() ?? 0 }

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
                Text("사진 \(items.count)장")
            } footer: {
                Text(items.isEmpty ? "사진이 없습니다." : "오른쪽 위 편집 → 끌어서 순서 변경, 왼쪽으로 밀어 삭제. 바꾼 순서가 카메라 화면에 그대로 보입니다.")
            }

            if hiddenCount > 0 {
                Section {
                    Button("지운 기본 사진 \(hiddenCount)장 되돌리기") {
                        layers.restoreHiddenMY(inPackage: packageID)
                    }
                } footer: {
                    Text("앱에 넣어 둔 사진은 지워도 다시 되돌릴 수 있습니다. 목록 맨 아래에 붙습니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("포즈 \(package?.name ?? "")")
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
