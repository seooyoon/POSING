//
//  TopControlsCapsule.swift
//  포징
//
//  상단 오른쪽 묶음: 플래시 · LIVE · •••
//  기본 카메라의 야간 모드 아이콘은 만들 수 없어서 뺐다 (CLAUDE.md 4절 3번).
//  비디오 모드에서는 LIVE가 없다.
//

import SwiftUI

struct TopControlsCapsule<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        HStack(spacing: 18) {
            Button {
                // 플래시 자동 → 켬 → 끔은 4단계에서 연결
            } label: {
                Image(systemName: "bolt.slash")
            }

            if camera.captureMode == .photo {
                Button {
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    Image(systemName: camera.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                        .foregroundStyle(camera.isLivePhotoEnabled ? Color.cameraYellow : .white)
                }
            }

            Button {
                // 더보기 메뉴는 4단계에서 연결
            } label: {
                MoreIcon()
            }
        }
        .buttonStyle(.plain)
        .topBarCapsule(horizontalPadding: 14)
    }
}

/// 기본 카메라의 더보기 아이콘 (점 3개 × 2줄)
private struct MoreIcon: View {
    var body: some View {
        VStack(spacing: -10) {
            Image(systemName: "ellipsis")
            Image(systemName: "ellipsis")
        }
        .font(.system(size: 13, weight: .heavy))
    }
}

#Preview {
    VStack {
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .photo))
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .video))
    }
    .padding()
    .background(.gray)
}
