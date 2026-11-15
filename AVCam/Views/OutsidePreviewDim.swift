//
//  OutsidePreviewDim.swift
//  포징
//
//  미리보기 바깥 덮개 (docs/02_UI.md 5절). 바깥은 검정이고, 1:1 · 16:9에서 잘려 나가는 4:3 부분만 어둡게 비친다.
//  넓은 장면으로 바깥을 채우는 것은 여행 뒤 메인 · 초광각을 따로 켜는 방식으로 다시 검토 (#97).
//

import SwiftUI

/// 미리보기 자리 바깥을 어둡게 덮음. 1:1 · 16:9에서 잘려 나가는 4:3 영상 부분이 반투명하게 보임
/// 비치지 않을 때(isSeeThrough = false)는 바깥 전체가 같이 검정 (기본 카메라와 같은 규칙)
struct OutsidePreviewDim: View {

    let previewRect: CGRect
    let isSeeThrough: Bool

    var body: some View {
        Color.black
            .opacity(isSeeThrough ? AppDefaults.outsidePreviewDimOpacity : 1)
            .mask {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                    // 미리보기 자리만 뚫음 (비율을 바꿀 때 자리와 같이 움직임)
                    Rectangle()
                        .frame(width: previewRect.width, height: previewRect.height)
                        .offset(x: previewRect.minX, y: previewRect.minY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}
