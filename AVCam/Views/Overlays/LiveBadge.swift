//
//  LiveBadge.swift
//  포징
//
//  미리보기 위쪽 가운데 LIVE 표시 (기본 카메라 모양).
//  켜져 있으면 노란 판 "LIVE", 꺼지면 흰 판 "LIVE 끔". 글자는 어두운 색.
//

import SwiftUI

struct LiveBadge: View {

    var isOn = true

    var body: some View {
        Text(isOn ? "LIVE" : "LIVE 끔")
            .font(.system(size: 15, weight: .medium))
            .tracking(1)
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(isOn ? Color.cameraYellow : .white, in: .rect(cornerRadius: 6))
    }
}

#Preview {
    VStack {
        LiveBadge()
        LiveBadge(isOn: false)
    }
    .padding()
    .background(.gray)
}
