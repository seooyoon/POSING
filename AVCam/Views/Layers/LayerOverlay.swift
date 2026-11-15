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
    /// 폰을 가로로 돌리면 MY 사진도 같이 돌려 똑바로 보이게 (포즈 테두리는 그대로)
    @Environment(\.iconAngle) private var angle

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
        let isPeeking = kind == .my && layers.isPeekingMY
        // 가로일 때는 가로세로를 바꾼 칸을 채운 뒤 돌림 → 돌린 결과가 원래 칸에 꼭 맞음
        let angle = kind == .my ? angle : 0
        let isSideways = abs(angle) > 45
        let box = isSideways ? CGSize(width: size.height, height: size.width) : size
        if let image = slot.image {
            ZStack {
                fitted(image, kind: kind, size: box)
                    .opacity(isPeeking ? 1 : slot.opacity)
                // MY 외곽선 · 얼굴 점은 투명도와 상관없이 진하게. 원본 보기 중에는 숨김.
                // 그림자는 가이드 이미지에 미리 그려 둠 (여기서 .shadow를 걸면 분할 칸 보기에서 화면이 멈춘 듯 밀림)
                if let guide = slot.guide {
                    fitted(guide, kind: kind, size: box)
                        .opacity(isPeeking ? 0 : 1)
                }
            }
            .rotationEffect(.degrees(angle))
            .frame(width: size.width, height: size.height)
            .animation(.easeInOut(duration: AppDefaults.iconRotationDuration), value: angle)
        }
    }

    /// 포즈 테두리는 촬영 범위 안에 맞추고, MY 사진(+ 같은 비율의 가이드)은 꽉 채움. 둘 다 가운데
    private func fitted(_ image: UIImage, kind: LayerKind, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: kind == .pose ? .fit : .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}
