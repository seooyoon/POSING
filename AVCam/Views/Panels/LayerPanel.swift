//
//  LayerPanel.swift
//  포징
//
//  포즈 · MY 공통 패널: 가로 목록 한 줄 + 투명도 조절 바 (docs/01_SPEC.md 3절, docs/02_UI.md 3절).
//  목록 칸은 꾹 눌러도 아무 동작 없다. 편집은 설정 화면에서만.
//

import SwiftUI

struct LayerPanel: View {

    @Bindable var layers: LayerState
    let kind: LayerKind

    private let thumbnailSize: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .my && layers.my.items.isEmpty {
                emptyMessage
            } else {
                list
            }
            OpacitySlider(value: $layers[kind].opacity, isEnabled: layers[kind].isSelected)
                .padding(.horizontal, CameraLayout.sideInset)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45))
    }

    private var list: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // 왼쪽 정렬, 좌우로 밀어서 스크롤
            LazyHStack(spacing: 8) {
                ForEach(layers[kind].items) { item in
                    thumbnail(item)
                }
            }
            .padding(.horizontal, CameraLayout.sideInset)
        }
        .frame(height: thumbnailSize)
    }

    private func thumbnail(_ item: LayerItem) -> some View {
        let isSelected = layers[kind].selectedID == item.id
        return Image(uiImage: item.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.cameraYellow, lineWidth: isSelected ? 2 : 0)
            }
            .contentShape(.rect(cornerRadius: 8))
            .onTapGesture {
                layers.toggle(item, in: kind)
            }
    }

    private var emptyMessage: some View {
        Text("MY를 꾹 눌러 사진을 추가하세요")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.8))
            .frame(height: thumbnailSize)
            .padding(.horizontal, CameraLayout.sideInset)
    }
}

#Preview {
    LayerPanel(layers: LayerState(), kind: .my)
        .background(.gray)
}
