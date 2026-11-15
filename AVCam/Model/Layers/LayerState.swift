//
//  LayerState.swift
//  포징
//
//  포즈 · MY 선택 상태와 열린 패널 (docs/01_SPEC.md 2~5절).
//  포즈 1개 + MY 1개까지 동시에 선택하고, 패널은 한 번에 하나만 연다.
//

import SwiftUI

/// 레이어 한 종류(포즈 또는 MY)의 목록과 선택 상태
struct LayerSlot {
    var items: [LayerItem] = []
    private(set) var selectedID: String?
    /// 화면에 겹치는 이미지. 고른 뒤 메인 스레드 밖에서 읽어 채움
    private(set) var image: UIImage?
    /// MY 사진의 외곽선 · 얼굴 점 (사진을 다 읽은 뒤 따로 채움). 포즈는 항상 nil
    private(set) var guide: UIImage?
    var opacity: Double
    let defaultOpacity: Double

    init(defaultOpacity: Double) {
        self.defaultOpacity = defaultOpacity
        opacity = defaultOpacity
    }

    var isSelected: Bool { selectedID != nil }

    /// 새 칸을 고르면 교체, 선택된 칸을 다시 고르면 해제
    mutating func toggle(_ item: LayerItem) {
        if selectedID == item.id {
            deselect()
        } else {
            select(item)
        }
    }

    /// 새로 고를 때마다 투명도는 기본값에서 시작 (CLAUDE.md 6절)
    mutating func select(_ item: LayerItem) {
        selectedID = item.id
        image = nil
        guide = nil
        opacity = defaultOpacity
    }

    /// 다 읽은 이미지를 적용. 그 사이 다른 칸으로 바뀌었으면 버림
    mutating func setImage(_ image: UIImage?, for id: String) {
        guard selectedID == id else { return }
        self.image = image
    }

    mutating func setGuide(_ guide: UIImage?, for id: String) {
        guard selectedID == id else { return }
        self.guide = guide
    }

    mutating func deselect() {
        selectedID = nil
        image = nil
        guide = nil
    }
}

@MainActor
@Observable
final class LayerState {

    var pose = LayerSlot(defaultOpacity: AppDefaults.poseOpacity)
    /// MY 선택 상태. 사진 목록은 패키지마다 따로 (`myPackages`)
    var my = LayerSlot(defaultOpacity: AppDefaults.myOpacity)
    /// 앱에 넣어 둔 MY 패키지 (순서 고정) + 패키지마다 직접 추가한 사진
    private(set) var myPackages: [MYPackage]
    /// MY 패널에서 들어가 있는 패키지. nil이면 패키지 목록. 패널을 닫았다 열어도 그대로
    private(set) var openMYPackageID: String?
    /// 지금 열린 패널. 포즈 · MY 패널은 같은 자리에 하나만
    private(set) var openPanel: LayerKind?
    /// 패키지 대표 이미지 꾹 누르기로 그 패키지에 사진을 추가하는 피커를 띄움
    var pickingMYPackageID: String?
    /// MY 버튼을 누르고 있는 동안 원본 사진을 100%로 (가이드는 숨김)
    var isPeekingMY = false
    /// 초기화 꾹 누르기로 설정 화면을 띄움
    var isShowingSettings = false

    init(poses: [LayerItem] = PoseLibrary.load(), myPackages: [MYPackage] = MYPackageLibrary.load()) {
        self.myPackages = myPackages
        pose.items = poses
    }

    subscript(kind: LayerKind) -> LayerSlot {
        get { kind == .pose ? pose : my }
        set {
            if kind == .pose { pose = newValue } else { my = newValue }
        }
    }

    var hasSelection: Bool { pose.isSelected || my.isSelected }

    /// 같은 버튼을 다시 누르면 닫고, 다른 버튼이면 그 패널로 바꿈
    func togglePanel(_ kind: LayerKind) {
        openPanel = openPanel == kind ? nil : kind
    }

    /// 미리보기를 탭하면 열린 패널만 닫음 (선택한 레이어는 그대로)
    func closePanel() {
        openPanel = nil
    }

    // MARK: - MY 패키지

    /// 패키지 목록에서 패키지를 누르면 그 안으로
    func openMYPackage(_ id: String) {
        openMYPackageID = id
    }

    /// 패키지 안에서 맨 왼쪽 대표 이미지를 누르면 다시 패키지 목록으로
    func closeMYPackage() {
        openMYPackageID = nil
    }

    func myPackage(_ id: String) -> MYPackage? {
        myPackages.first { $0.id == id }
    }

    func toggle(_ item: LayerItem, in kind: LayerKind) {
        self[kind].toggle(item)
        loadImage(of: item, in: kind)
    }

    /// 초기화 탭: 선택 해제 + 패널 닫기. 목록은 그대로
    func reset() {
        pose.deselect()
        my.deselect()
        openPanel = nil
    }

    /// 새로 추가한 사진을 고른 순서대로 그 패키지 맨 왼쪽에 놓고, 1번을 바로 적용 + 그 패키지를 연 MY 패널.
    /// 이미 있던 사진은 중복으로 쌓지 않고 맨 왼쪽으로 옮김
    func addMY(_ newItems: [LayerItem], to packageID: String) {
        guard let index = myPackages.firstIndex(where: { $0.id == packageID }) else { return }
        let added = myPackages[index].addedItems
        // 이미 있던 사진은 붙여 둔 이름을 그대로 씀
        let newItems = newItems.map { item in
            var item = item
            item.name = added.first { $0.id == item.id }?.name ?? ""
            return item
        }
        guard let first = newItems.first else { return }
        let newIDs = Set(newItems.map(\.id))
        myPackages[index].addedItems = newItems + added.filter { !newIDs.contains($0.id) }
        my.select(first)
        loadImage(of: first, in: .my)
        openPanel = .my
        openMYPackageID = packageID
        myPackages[index].library.saveOrder(myPackages[index].addedItems)
    }

    // MARK: - 설정 화면 목록 편집

    func movePoses(from source: IndexSet, to destination: Int) {
        pose.items.move(fromOffsets: source, toOffset: destination)
        PoseLibrary.saveOrder(pose.items)
    }

    func moveMY(inPackage packageID: String, from source: IndexSet, to destination: Int) {
        editAdded(inPackage: packageID) { items, library in
            items.move(fromOffsets: source, toOffset: destination)
            library.saveOrder(items)
        }
    }

    /// 추가한 사진 이름 (띄어쓰기 포함 최대 10자). 넘치는 입력은 받지 않고 이전 이름 유지
    func renameMY(_ id: String, inPackage packageID: String, to name: String) {
        guard name.count <= MYLibrary.maxNameLength else { return }
        editAdded(inPackage: packageID) { items, library in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].name = name
            library.saveNames(items)
        }
    }

    /// 선택 중인 사진을 지우면 화면의 MY 레이어도 사라짐
    func deleteMY(inPackage packageID: String, at offsets: IndexSet) {
        editAdded(inPackage: packageID) { items, library in
            let removed = offsets.map { items[$0] }
            if removed.contains(where: { $0.id == my.selectedID }) {
                my.deselect()
            }
            items.remove(atOffsets: offsets)
            library.delete(removed)
            library.saveOrder(items)
            library.saveNames(items)
        }
    }

    /// 패키지의 추가한 사진 목록을 고치고 다시 넣음
    private func editAdded(inPackage packageID: String, _ edit: (inout [LayerItem], MYLibrary) -> Void) {
        guard let index = myPackages.firstIndex(where: { $0.id == packageID }) else { return }
        var items = myPackages[index].addedItems
        edit(&items, myPackages[index].library)
        myPackages[index].addedItems = items
    }

    // MARK: - 이미지 읽기

    /// 선택된 칸의 큰 이미지를 메인 스레드 밖에서 읽고 화면용으로 미리 풀어 둠
    private func loadImage(of item: LayerItem, in kind: LayerKind) {
        guard self[kind].selectedID == item.id else { return }
        let url = item.imageURL
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                await UIImage(contentsOfFile: url.path)?.byPreparingForDisplay()
            }.value
            self[kind].setImage(image, for: item.id)
            // MY는 사진을 먼저 보여주고, 외곽선 · 얼굴 점은 인식이 끝나면 덧그림
            guard kind == .my, let image, self[kind].selectedID == item.id else { return }
            let guide = await Task.detached(priority: .userInitiated) {
                MYGuideMaker.guide(for: image)?.preparingForDisplay()
            }.value
            self[kind].setGuide(guide, for: item.id)
        }
    }
}
