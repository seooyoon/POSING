//
//  TopControlsCapsule.swift
//  포징
//
//  상단 오른쪽 묶음: [스타일] · 플래시 · LIVE · •••. 꾹 누르면 플래시 · LIVE 빠른 설정 판
//  표준이 아닌 스타일을 쓰는 동안 기본 카메라처럼 맨 앞에 노란 스타일 아이콘 (누르면 스타일 화면)
//  기본 카메라의 야간 모드 아이콘은 만들 수 없어서 뺐다 (CLAUDE.md 4절 3번).
//  비디오 모드에서는 LIVE가 없고, 플래시는 조명(전면은 조명이 없어 숨김).
//

import SwiftUI

struct TopControlsCapsule<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @Binding var isShowingMoreMenu: Bool
    @Binding var quickSettings: QuickSettingsKind?
    /// 스타일 아이콘을 누르면 스타일 화면
    var onShowStyle: () -> Void = {}

    /// 표준이 아닌 스타일을 쓰는 중 (사진 모드만)
    private var showsStyle: Bool {
        camera.captureMode == .photo && camera.photoStyle.changesImage
    }

    /// 아이콘 하나의 폭. 스타일 아이콘까지 4개면 상단 바가 넘치지 않게 좁힘
    private var iconWidth: CGFloat {
        showsStyle ? AppDefaults.topCapsuleCompactIconWidth : AppDefaults.topCapsuleIconWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            if showsStyle {
                Button {
                    guard quickSettings == nil else { return }
                    isShowingMoreMenu = false
                    onShowStyle()
                } label: {
                    StyleIcon(size: AppDefaults.topCapsuleStyleIconSize)
                        .foregroundStyle(Color.cameraYellow)
                        .tapTarget(width: iconWidth)
                }
                .accessibilityLabel("스타일")
                .transition(.opacity)
            }

            if !(camera.captureMode.isMovie && camera.zoom.isFrontCamera) {
                Button {
                    guard quickSettings == nil else { return }
                    camera.flashMode = camera.flashMode.next
                } label: {
                    Image(systemName: camera.flashMode.symbolName)
                        .foregroundStyle(camera.flashMode == .on ? Color.cameraYellow : .white)
                        .tapTarget(width: iconWidth)
                }
            }

            if camera.captureMode == .photo {
                Button {
                    guard quickSettings == nil else { return }
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    Image(systemName: camera.isLivePhotoActive ? "livephoto" : "livephoto.slash")
                        .foregroundStyle(camera.isLivePhotoActive ? Color.cameraYellow : .white)
                        .tapTarget(width: iconWidth)
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
                    .tapTarget(width: iconWidth)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: showsStyle)
        .topBarCapsule(horizontalPadding: 5)
        // 꾹 누르면 기본 카메라처럼 플래시 · LIVE 빠른 설정 판
        .simultaneousGesture(
            LongPressGesture(minimumDuration: AppDefaults.longPressDuration).onEnded { _ in
                // 전면 비디오는 플래시 · LIVE가 모두 없어 판을 열지 않음
                guard !(camera.captureMode.isMovie && camera.zoom.isFrontCamera) else { return }
                isShowingMoreMenu = false
                quickSettings = .flashAndLive
            }
        )
    }
}

private extension View {
    /// 아이콘 하나의 터치 범위: 아이콘 사이 간격까지 채우고 캡슐 위아래로도 조금 넓힘
    func tapTarget(width: CGFloat) -> some View {
        frame(width: width, height: topBarControlHeight)
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
