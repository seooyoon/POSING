//
//  TopControlsCapsule.swift
//  포징
//
//  상단 오른쪽 묶음: 플래시 · LIVE · •••
//  기본 카메라의 야간 모드 아이콘은 만들 수 없어서 뺐다 (CLAUDE.md 4절 3번).
//  비디오 모드에서는 LIVE가 없고, 플래시는 조명(전면은 조명이 없어 숨김).
//

import SwiftUI

struct TopControlsCapsule<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var isShowingMoreMenu: Bool

    var body: some View {
        HStack(spacing: 18) {
            if !(camera.captureMode == .video && camera.zoom.isFrontCamera) {
                Button {
                    camera.flashMode = camera.flashMode.next
                } label: {
                    Image(systemName: camera.flashMode.symbolName)
                        .foregroundStyle(camera.flashMode == .on ? Color.cameraYellow : .white)
                }
            }

            if camera.captureMode == .photo {
                Button {
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    Image(systemName: camera.isLivePhotoActive ? "livephoto" : "livephoto.slash")
                        .foregroundStyle(camera.isLivePhotoActive ? Color.cameraYellow : .white)
                }
                // 비율이 4:3이 아니면 LIVE 자동 끔 (꺼짐 표시)
                .disabled(camera.photoAspect != .fourThree)
            }

            Button {
                isShowingMoreMenu.toggle()
            } label: {
                MoreIcon()
                    .foregroundStyle(isShowingMoreMenu ? Color.cameraYellow : .white)
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
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .photo), isShowingMoreMenu: .constant(false))
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .video), isShowingMoreMenu: .constant(true))
    }
    .padding()
    .background(.gray)
}
