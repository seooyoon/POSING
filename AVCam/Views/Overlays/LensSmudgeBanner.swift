//
//  LensSmudgeBanner.swift
//  포징
//
//  렌즈에 얼룩이 감지되면 보이는 "카메라 렌즈를 청소하십시오. ✕" 안내 (기본 카메라 "Clean Back Camera"와 같은 모양).
//  ✕를 누르면 닫히고, 얼룩이 사라졌다가 다시 감지되면 다시 보인다.
//

import SwiftUI

struct LensSmudgeBanner: View {

    let isSmudged: Bool

    @State private var isDismissed = false

    var body: some View {
        ZStack {
            if isSmudged && !isDismissed {
                Button {
                    withAnimation { isDismissed = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("카메라 렌즈를 청소하십시오.")
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45), in: .rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .onChange(of: isSmudged) { _, smudged in
            // 깨끗해지면 다음 감지 때 다시 보이게
            if !smudged { isDismissed = false }
        }
    }
}

#Preview {
    LensSmudgeBanner(isSmudged: true)
        .padding()
        .background(.gray)
}
