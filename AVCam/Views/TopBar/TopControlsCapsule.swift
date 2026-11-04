//
//  TopControlsCapsule.swift
//  포징
//
//  상단 오른쪽 묶음: 플래시 · LIVE · •••. 꾹 누르면 플래시 · LIVE 빠른 설정 판
//  기본 카메라의 야간 모드 아이콘은 만들 수 없어서 뺐다 (CLAUDE.md 4절 3번).
//  비디오 모드에서는 LIVE가 없고, 플래시는 조명(전면은 조명이 없어 숨김).
//

import SwiftUI

struct TopControlsCapsule<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var isShowingMoreMenu: Bool
    @Binding var quickSettings: QuickSettingsKind?

    var body: some View {
        HStack(spacing: 0) {
            if !(camera.captureMode == .video && camera.zoom.isFrontCamera) {
                Button {
                    guard quickSettings == nil else { return }
                    camera.flashMode = camera.flashMode.next
                } label: {
                    Image(systemName: camera.flashMode.symbolName)
                        .foregroundStyle(camera.flashMode == .on ? Color.cameraYellow : .white)
                        .tapTarget()
                }
            }

            if camera.captureMode == .photo {
                Button {
                    guard quickSettings == nil else { return }
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    Image(systemName: camera.isLivePhotoActive ? "livephoto" : "livephoto.slash")
                        .foregroundStyle(camera.isLivePhotoActive ? Color.cameraYellow : .white)
                        .tapTarget()
                }
                // 비율이 4:3이 아니거나 RAW면 LIVE 자동 끔 (꺼짐 표시)
                .disabled(!camera.isLivePhotoAvailable)
            }

            Button {
                // 꾹 눌러 빠른 설정 판을 연 뒤 손을 뗄 때는 메뉴를 열지 않음
                guard quickSettings == nil else { return }
                isShowingMoreMenu.toggle()
            } label: {
                MoreIcon()
                    .foregroundStyle(isShowingMoreMenu ? Color.cameraYellow : .white)
                    .tapTarget()
            }
        }
        .buttonStyle(.plain)
        .topBarCapsule(horizontalPadding: 5)
        // 꾹 누르면 기본 카메라처럼 플래시 · LIVE 빠른 설정 판
        .simultaneousGesture(
            LongPressGesture(minimumDuration: AppDefaults.longPressDuration).onEnded { _ in
                // 전면 비디오는 플래시 · LIVE가 모두 없어 판을 열지 않음
                guard !(camera.captureMode == .video && camera.zoom.isFrontCamera) else { return }
                isShowingMoreMenu = false
                quickSettings = .flashAndLive
            }
        )
    }
}

private extension View {
    /// 아이콘 하나의 터치 범위: 아이콘 사이 간격까지 채우고 캡슐 위아래로도 조금 넓힘
    func tapTarget() -> some View {
        frame(width: 38, height: topBarControlHeight)
            .contentShape(Rectangle().inset(by: -6))
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
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .photo), isShowingMoreMenu: .constant(false), quickSettings: .constant(nil))
        TopControlsCapsule(camera: PreviewCameraModel(captureMode: .video), isShowingMoreMenu: .constant(true), quickSettings: .constant(nil))
    }
    .padding()
    .background(.gray)
}
