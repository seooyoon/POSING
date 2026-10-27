//
//  LayerOverlay.swift
//  포징
//
//  미리보기 위에 겹치는 MY 사진(아래) · 포즈 테두리(위). 화면에만 그리고 저장본에는 넣지 않는다 (CLAUDE.md 4절 1번).
//  레이어는 손으로 조작하지 않고, 화면 탭 · 밀기는 아래 미리보기로 그대로 넘긴다.
//

import SwiftUI

struct LayerOverlay: View {

    let layers: LayerState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                layer(.my, size: proxy.size)
                layer(.pose, size: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func layer(_ kind: LayerKind, size: CGSize) -> some View {
        let slot = layers[kind]
        if let image = slot.image {
            Image(uiImage: image)
                .resizable()
                // 포즈 테두리는 촬영 범위 안에 맞추고, MY 사진은 꽉 채움. 둘 다 가운데
                .aspectRatio(contentMode: kind == .pose ? .fit : .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(slot.opacity)
        }
    }
}
