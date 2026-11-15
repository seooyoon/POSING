//
//  LayerPanel.swift
//  포징
//
//  포즈 · MY 공통 패널: 가로 목록 한 줄 + 투명도 조절 바 (docs/01_SPEC.md 3절, docs/02_UI.md 3절).
//  MY는 패키지 목록 → 패키지 안(대표 이미지 맨 왼쪽 고정 + 사진들) 두 단계.
//  대표 이미지를 꾹 누르면 그 패키지에 사진 추가. 사진 칸은 꾹 눌러도 아무 동작 없다. 편집은 설정 화면에서만.
//

import SwiftUI

struct LayerPanel: View {

    @Bindable var layers: LayerState
    let kind: LayerKind

    private let thumbnailSize: CGFloat = 56
    /// MY 칸 아래 이름 줄 높이 (패키지 목록 · 패키지 안 높이를 같게)
    private let nameHeight: CGFloat = 16
    /// 꾹 눌러 살짝 커졌다 돌아오는 대표 이미지
    @State private var poppedPackageID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .pose {
                list(layers.pose.items, showsNames: false)
            } else if let packageID = layers.openMYPackageID {
                packageContents(packageID)
            } else {
                packageList
            }
            OpacitySlider(value: $layers[kind].opacity, isEnabled: layers[kind].isSelected, range: AppDefaults.opacityRange(for: kind))
                .padding(.horizontal, CameraLayout.sideInset)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45))
        .animation(.easeOut(duration: 0.2), value: layers.openMYPackageID)
    }

    // MARK: - 목록

    private func list(_ items: [LayerItem], showsNames: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // 왼쪽 정렬, 좌우로 밀어서 스크롤
            LazyHStack(alignment: .top, spacing: 8) {
                ForEach(items) { item in
                    thumbnail(item, showsName: showsNames)
                }
            }
            .padding(.horizontal, CameraLayout.sideInset)
        }
        .frame(height: showsNames ? thumbnailSize + nameHeight : thumbnailSize)
    }

    private func thumbnail(_ item: LayerItem, showsName: Bool) -> some View {
        let isSelected = layers[kind].selectedID == item.id
        return VStack(spacing: 2) {
            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.cameraYellow, lineWidth: isSelected ? 2 : 0)
                }
            if showsName {
                // 설정에서 붙인 MY 사진 이름 (없으면 빈 줄)
                nameLabel(item.name)
            }
        }
        .contentShape(.rect(cornerRadius: 8))
        .onTapGesture {
            layers.toggle(item, in: kind)
        }
    }

    // MARK: - MY 패키지

    /// 패키지 목록: 앱에 넣어 둔 패키지 (순서 고정)
    private var packageList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 8) {
                ForEach(layers.myPackages) { package in
                    packageCell(package)
                }
            }
            .padding(.horizontal, CameraLayout.sideInset)
        }
        .frame(height: thumbnailSize + nameHeight)
    }

    /// 패키지 안: 대표 이미지는 맨 왼쪽에 고정 (누르면 목록으로), 오른쪽에 사진들
    @ViewBuilder
    private func packageContents(_ id: String) -> some View {
        if let package = layers.myPackage(id) {
            HStack(alignment: .top, spacing: 0) {
                packageCell(package)
                    .padding(.leading, CameraLayout.sideInset)
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: thumbnailSize - 12)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                list(package.items, showsNames: true)
                    .contentMargins(.leading, 0, for: .scrollContent)
            }
            .transition(.opacity)
        }
    }

    /// 패키지 칸: 대표 이미지 + 아래 이름. 목록에서는 들어가기, 패키지 안에서는 목록으로 돌아가기.
    /// 꾹 누르면 그 패키지에 사진 추가
    private func packageCell(_ package: MYPackage) -> some View {
        let isOpen = layers.openMYPackageID == package.id
        return VStack(spacing: 2) {
            Image(uiImage: package.cover)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize, height: thumbnailSize)
                // 대표 이미지에는 노란 테두리 없음 (선택 표시는 사진 칸에만)
                .clipShape(.rect(cornerRadius: 8))
                .scaleEffect(poppedPackageID == package.id ? 1.08 : 1)
            nameLabel(package.name)
        }
        .contentShape(.rect(cornerRadius: 8))
        .onTapGesture {
            if isOpen { layers.closeMYPackage() } else { layers.openMYPackage(package.id) }
        }
        .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
            addPhotos(to: package.id)
        }
        .accessibilityElement()
        .accessibilityLabel(package.name)
        .accessibilityHint(isOpen ? "패키지 목록으로" : "패키지 열기")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "사진 추가") { addPhotos(to: package.id) }
    }

    /// 꾹 누르기 인식 시 살짝 커졌다 돌아오고 사진 피커를 띄움
    private func addPhotos(to id: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            poppedPackageID = id
        } completion: {
            withAnimation(.easeIn(duration: 0.12)) {
                poppedPackageID = nil
            }
        }
        layers.pickingMYPackageID = id
    }

    private func nameLabel(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .frame(width: thumbnailSize + 8, height: nameHeight)
    }
}

#Preview {
    LayerPanel(layers: LayerState(), kind: .my)
        .background(.gray)
}
