//
//  SettingsView.swift
//  포징
//
//  초기화 꾹 누르기로 여는 설정 화면 (docs/01_SPEC.md 6절, docs/02_UI.md 4절).
//  아이폰 설정 앱 > 카메라와 같은 스타일. 카메라 화면과 달리 시스템 밝은/어두운 모드를 따른다.
//  맨 위는 앱 아이콘 카드 (docs/01_SPEC.md 6절 "앱 아이콘", docs/05_TECH_NOTES.md 16절).
//

import SwiftUI

struct SettingsView: View {

    let layers: LayerState
    let looks: CameraLookState

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.isGridEnabled) private var isGridEnabled = AppDefaults.isGridEnabled
    @AppStorage(SettingsKeys.isCenterMarkEnabled) private var isCenterMarkEnabled = AppDefaults.isCenterMarkEnabled

    var body: some View {
        NavigationStack {
            List {
                // 잠금 화면 캡처 확장에서는 앱 아이콘을 바꿀 수 없음
                #if !APP_EXTENSION
                if UIApplication.shared.supportsAlternateIcons {
                    Section("앱 아이콘") {
                        AppIconCard()
                    }
                }
                #endif

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
                    NavigationLink {
                        CameraOrderView(looks: looks)
                    } label: {
                        LabeledContent("카메라 목록", value: looks.startItem?.name ?? "")
                    }
                } header: {
                    Text("목록")
                } footer: {
                    Text("포즈 · MY는 바꾼 순서가 카메라 화면 목록에 그대로 보입니다. 카메라 목록 오른쪽 이름은 앱을 켤 때 쓰는 카메라입니다.")
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

// MARK: - 앱 아이콘

/// 고를 수 있는 홈 화면 아이콘. id = 아이콘 세트 이름 (기본은 nil), preview = 목록용 작은 이미지
struct AppIconOption: Identifiable {
    let id: String?
    let name: String
    let preview: String

    /// 기본 + 추가 12개, 설정에 보이는 순서대로 (번호 = Assets의 AppIcon-XX · IconPreview-XX)
    static let all: [AppIconOption] = {
        let extras: [(number: Int, name: String)] = [
            (1, "사람"), (11, "파랑 로고"), (12, "검정 로고"), (10, "토끼"), (2, "강아지"), (3, "고양이"),
            (5, "닭"), (6, "병아리"), (7, "쥐"), (8, "돼지"), (9, "원숭이"), (4, "구름"),
        ]
        return [AppIconOption(id: nil, name: "기본", preview: "IconPreview-00")] + extras.map { extra in
            let number = String(format: "%02d", extra.number)
            return AppIconOption(id: "AppIcon-\(number)", name: extra.name, preview: "IconPreview-\(number)")
        }
    }()

    static func option(for id: String?) -> AppIconOption {
        all.first { $0.id == id } ?? all[0]
    }
}

#if !APP_EXTENSION
/// 설정 맨 위 카드: 평소엔 지금 아이콘 + 수정. 수정 → 가로 아이콘 목록 + 취소 · 확인 (확인해야 바뀜)
struct AppIconCard: View {

    @State private var current = UIApplication.shared.alternateIconName
    @State private var picked: String?
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                AppIconThumbnail(option: .option(for: current), size: AppDefaults.appIconCurrentSize)
                Text(AppIconOption.option(for: current).name)
                Spacer()
                if !isEditing {
                    Button("수정") {
                        picked = current
                        withAnimation { isEditing = true }
                    }
                    .buttonStyle(.borderless)
                }
            }
            if isEditing {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(AppIconOption.all) { option in
                            iconChoice(option)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                HStack {
                    Button("취소") {
                        withAnimation { isEditing = false }
                    }
                    Spacer()
                    Button("확인") { apply() }
                        .fontWeight(.semibold)
                        .disabled(picked == current)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    /// 목록의 아이콘 하나: 탭하면 선택 표시만 바뀜. 고른 아이콘은 파란 테두리 + 체크
    private func iconChoice(_ option: AppIconOption) -> some View {
        let isPicked = option.id == picked
        return Button {
            picked = option.id
        } label: {
            VStack(spacing: 6) {
                AppIconThumbnail(option: option, size: AppDefaults.appIconListSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppIconThumbnail.cornerRadius(AppDefaults.appIconListSize) + 3, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: isPicked ? 2.5 : 0)
                            .padding(-4)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isPicked {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .font(.system(size: 18))
                                .offset(x: 6, y: 6)
                        }
                    }
                // 고른 아이콘만 노랑, 나머지는 검정 글씨 (다크 모드면 흰 글씨).
                // `.primary`는 버튼 안에서 노랑(tint)으로 바뀌어서 `Color.primary`를 직접 씀
                Text(option.name)
                    .font(.caption)
                    .foregroundStyle(isPicked ? Color.accentColor : Color.primary)
                    .lineLimit(1)
            }
            .frame(width: AppDefaults.appIconListSize + 12)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// 홈 화면 아이콘 바꾸기. 바꾼 뒤 iOS가 알림을 한 번 띄움 (막을 수 없음)
    private func apply() {
        let target = picked
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(target)
                current = target
            } catch {
                // 실패하면 그대로 둠
                current = UIApplication.shared.alternateIconName
            }
            withAnimation { isEditing = false }
        }
    }
}

#endif

/// 홈 화면 아이콘처럼 둥근 사각형으로 자른 미리보기
struct AppIconThumbnail: View {
    let option: AppIconOption
    let size: CGFloat

    /// iOS 아이콘 모서리 비율
    static func cornerRadius(_ size: CGFloat) -> CGFloat { size * 0.2237 }

    var body: some View {
        Image(option.preview)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: Self.cornerRadius(size), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius(size), style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    SettingsView(layers: LayerState(), looks: CameraLookState())
}
