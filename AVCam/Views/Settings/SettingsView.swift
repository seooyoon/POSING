//
//  SettingsView.swift
//  포징
//
//  초기화 꾹 누르기로 여는 설정 화면 (docs/01_SPEC.md 6절, docs/02_UI.md 4절).
//  아이폰 설정 앱 > 카메라와 같은 스타일. 카메라 화면과 달리 시스템 밝은/어두운 모드를 따른다.
//  앱 아이콘 카드는 7단계, 카메라 목록 줄은 5-1단계에서 추가한다.
//

import SwiftUI

struct SettingsView: View {

    let layers: LayerState

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.isGridEnabled) private var isGridEnabled = AppDefaults.isGridEnabled
    @AppStorage(SettingsKeys.isCenterMarkEnabled) private var isCenterMarkEnabled = AppDefaults.isCenterMarkEnabled

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("3x3 격자", isOn: $isGridEnabled)
                    Toggle("중심점", isOn: $isCenterMarkEnabled)
                } header: {
                    Text("화면 표시")
                } footer: {
                    Text("중심점은 화면 정가운데에 작은 십자(+)를 표시합니다.")
                }

                Section {
                    NavigationLink("포즈 목록") {
                        PoseOrderView(layers: layers)
                    }
                    NavigationLink("MY 목록") {
                        MYListView(layers: layers)
                    }
                } header: {
                    Text("목록")
                } footer: {
                    Text("바꾼 순서는 카메라 화면 목록에 왼쪽부터 그대로 보입니다.")
                }

                Section("정보") {
                    LabeledContent("버전", value: appVersion)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

#Preview {
    SettingsView(layers: LayerState())
}
