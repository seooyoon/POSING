//
//  LayerPanel.swift
//  포징
//
//  포즈 · MY 공통 패널: 가로 목록 한 줄 + 투명도 조절 바 (docs/01_SPEC.md 3절, docs/02_UI.md 3절).
//  MY는 패키지 목록 → 패키지 안(대표 이미지 맨 왼쪽 고정 + 사진들) 두 단계.
//  목록 칸은 꾹 눌러도 아무 동작 없다. 편집은 설정 화면에서만.
//

import SwiftUI

struct LayerPanel: View {

    @Bindable var layers: LayerState
    let kind: LayerKind

    private let thumbnailSize: CGFloat = 56
    /// MY 칸 아래 이름 줄 높이 (패키지 목록 · 패키지 안 높이를 같게)
    private let nameHeight: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .pose {
                list(layers.pose.items, showsNames: false)
            } else if let packageID = layers.openMYPackageID {
                packageContents(packageID)
            } else {
                packageList
            }
            OpacitySlider(value: $layers[kind].opacity, isEnabled: layers[kind].isSelected)
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

    /// 패키지 목록: 맨 왼쪽 '내 사진', 그다음 앱에 넣어 둔 패키지 (순서 고정)
    private var packageList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 8) {
                packageCell(id: LayerState.userPackageID, name: LayerState.userPackageID, cover: layers.userPackageCover)
                ForEach(layers.myPackages) { package in
                    packageCell(id: package.id, name: package.name, cover: package.cover)
                }
            }
            .padding(.horizontal, CameraLayout.sideInset)
        }
        .frame(height: thumbnailSize + nameHeight)
    }

    /// 패키지 안: 대표 이미지는 맨 왼쪽에 고정 (누르면 목록으로), 오른쪽에 사진들
    private func packageContents(_ id: String) -> some View {
        let isUser = id == LayerState.userPackageID
        let package = layers.myPackages.first { $0.id == id }
        let items = layers.myItems(inPackage: id)
        return HStack(alignment: .top, spacing: 0) {
            packageCell(id: id, name: package?.name ?? id, cover: isUser ? layers.userPackageCover : package?.cover)
                .padding(.leading, CameraLayout.sideInset)
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: thumbnailSize - 12)
                .padding(.horizontal, 8)
                .padding(.top, 6)
            if items.isEmpty {
                emptyMessage
            } else {
                list(items, showsNames: true)
                    .contentMargins(.leading, 0, for: .scrollContent)
            }
        }
        .transition(.opacity)
    }

    /// 패키지 칸: 대표 이미지 + 아래 이름. 목록에서는 들어가기, 패키지 안에서는 목록으로 돌아가기
    private func packageCell(id: String, name: String, cover: UIImage?) -> some View {
        let isOpen = layers.openMYPackageID == id
        return VStack(spacing: 2) {
            Group {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    // 아직 사진이 없는 '내 사진'
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.15))
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            // 대표 이미지에는 노란 테두리 없음 (선택 표시는 사진 칸에만)
            .clipShape(.rect(cornerRadius: 8))
            nameLabel(name)
        }
        .contentShape(.rect(cornerRadius: 8))
        .onTapGesture {
            if isOpen { layers.closeMYPackage() } else { layers.openMYPackage(id) }
        }
        .accessibilityElement()
        .accessibilityLabel(name)
        .accessibilityHint(isOpen ? "패키지 목록으로" : "패키지 열기")
        .accessibilityAddTraits(.isButton)
    }

    private func nameLabel(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .frame(width: thumbnailSize + 8, height: nameHeight)
    }

    private var emptyMessage: some View {
        Text("MY를 꾹 눌러 사진을 추가하세요")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.8))
            .frame(height: thumbnailSize)
            .padding(.trailing, CameraLayout.sideInset)
    }
}

#Preview {
    LayerPanel(layers: LayerState(), kind: .my)
        .background(.gray)
}
