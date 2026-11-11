//
//  CameraOrderView.swift
//  포징
//
//  설정 > 카메라 목록: 탭해서 시작 카메라를 고르고, 두 번 빠르게 탭해 즐겨찾기. 순서는 즐겨찾기 먼저 · 이름순 고정, 추가 · 삭제 없음 (docs/01_SPEC.md 6절).
//

import SwiftUI

struct CameraOrderView: View {

    let looks: CameraLookState

    var body: some View {
        List {
            Section {
                ForEach(looks.items) { item in
                    row(item)
                }
            } footer: {
                Text("체크한 카메라로 앱이 시작됩니다. 카메라 화면에서 바꾼 카메라는 앱을 다시 켜면 이 카메라로 돌아갑니다. 두 번 빠르게 탭하면 즐겨찾기(♥)가 되고, 즐겨찾기가 먼저 보입니다. 순서는 이름순(가나다 · abc)입니다.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("카메라 목록")
    }

    /// 탭하면 시작 카메라로 고정, 두 번 빠르게 탭하면 즐겨찾기 켜고 끔
    private func row(_ item: CameraLookItem) -> some View {
        let isStart = looks.startItem?.id == item.id
        let isFavorite = looks.isFavorite(item)
        return HStack {
            SettingsThumbnailRow(image: item.image, title: item.name, fillsFrame: false)
            if isFavorite {
                FavoriteHeart(size: 20)
            }
            Spacer()
            if isStart {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(.rect)
        // 두 번 빠르게 탭 = 즐겨찾기 켜고 끔, 한 번 탭 = 시작 카메라
        .onTapGesture(count: 2) {
            withAnimation { looks.toggleFavorite(item) }
        }
        .onTapGesture { looks.setStart(item) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isStart ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isFavorite ? "즐겨찾기" : "")
        .accessibilityAction { looks.setStart(item) }
        .accessibilityAction(named: isFavorite ? "즐겨찾기 해제" : "즐겨찾기") { looks.toggleFavorite(item) }
    }
}
