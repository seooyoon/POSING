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
        opacity = defaultOpacity
    }

    /// 다 읽은 이미지를 적용. 그 사이 다른 칸으로 바뀌었으면 버림
    mutating func setImage(_ image: UIImage?, for id: String) {
        guard selectedID == id else { return }
        self.image = image
    }

    mutating func deselect() {
        selectedID = nil
        image = nil
    }
}

@MainActor
@Observable
final class LayerState {

    var pose = LayerSlot(defaultOpacity: AppDefaults.poseOpacity)
    /// MY 선택 상태. `my.items`는 직접 추가한 '내 사진' 패키지의 사진
    var my = LayerSlot(defaultOpacity: AppDefaults.myOpacity)
    /// 앱에 넣어 둔 MY 패키지 (순서 고정)
    let myPackages: [MYPackage]
    /// '내 사진' 대표 이미지로 직접 고른 사진. nil이면 첫 사진
    private(set) var myCustomCover: UIImage? = MYLibrary.loadCover()
    /// MY 패널에서 들어가 있는 패키지. nil이면 패키지 목록. 패널을 닫았다 열어도 그대로
    private(set) var openMYPackageID: String?
    /// 지금 열린 패널. 포즈 · MY 패널은 같은 자리에 하나만
    private(set) var openPanel: LayerKind?
    /// MY 꾹 누르기로 사진 피커를 띄움
    var isPickingMY = false
    /// 초기화 꾹 누르기로 설정 화면을 띄움
    var isShowingSettings = false

    /// 직접 추가한 사진 묶음의 id (패키지 목록 맨 왼쪽)
    static let userPackageID = "내 사진"

    init(poses: [LayerItem] = PoseLibrary.load(), myItems: [LayerItem] = MYLibrary.load(),
         myPackages: [MYPackage] = MYPackageLibrary.load()) {
        self.myPackages = myPackages
        pose.items = poses
        my.items = myItems
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

    /// '내 사진' 대표 이미지: 직접 고른 사진, 없으면 첫 사진
    var userPackageCover: UIImage? {
        myCustomCover ?? my.items.first?.thumbnail
    }

    /// 설정에서 고른 대표 이미지 적용. nil이면 첫 사진으로 되돌림
    func setMYCover(_ image: UIImage?) {
        if image == nil { MYLibrary.deleteCover() }
        myCustomCover = image
    }

    /// 패키지 안의 사진. '내 사진'은 직접 추가한 사진
    func myItems(inPackage id: String) -> [LayerItem] {
        id == Self.userPackageID ? my.items : myPackages.first { $0.id == id }?.items ?? []
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

    /// 새로 추가한 사진을 고른 순서대로 맨 왼쪽에 놓고, 1번을 바로 적용 + MY 패널 열기.
    /// 이미 있던 사진은 중복으로 쌓지 않고 맨 왼쪽으로 옮김
    func addMY(_ newItems: [LayerItem]) {
        // 이미 있던 사진은 붙여 둔 이름을 그대로 씀
        let newItems = newItems.map { item in
            var item = item
            item.name = my.items.first { $0.id == item.id }?.name ?? ""
            return item
        }
        guard let first = newItems.first else { return }
        let newIDs = Set(newItems.map(\.id))
        my.items = newItems + my.items.filter { !newIDs.contains($0.id) }
        my.select(first)
        loadImage(of: first, in: .my)
        openPanel = .my
        openMYPackageID = Self.userPackageID
        MYLibrary.saveOrder(my.items)
    }

    // MARK: - 설정 화면 목록 편집

    func movePoses(from source: IndexSet, to destination: Int) {
        pose.items.move(fromOffsets: source, toOffset: destination)
        PoseLibrary.saveOrder(pose.items)
    }

    func moveMY(from source: IndexSet, to destination: Int) {
        my.items.move(fromOffsets: source, toOffset: destination)
        MYLibrary.saveOrder(my.items)
    }

    /// MY 사진 이름 (띄어쓰기 포함 최대 10자). 넘치는 입력은 받지 않고 이전 이름 유지
    func renameMY(_ id: String, to name: String) {
        guard name.count <= MYLibrary.maxNameLength,
              let index = my.items.firstIndex(where: { $0.id == id })
        else { return }
        my.items[index].name = name
        MYLibrary.saveNames(my.items)
    }

    /// 선택 중인 사진을 지우면 화면의 MY 레이어도 사라짐
    func deleteMY(at offsets: IndexSet) {
        let removed = offsets.map { my.items[$0] }
        if removed.contains(where: { $0.id == my.selectedID }) {
            my.deselect()
        }
        my.items.remove(atOffsets: offsets)
        MYLibrary.delete(removed)
        MYLibrary.saveOrder(my.items)
        MYLibrary.saveNames(my.items)
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
        }
    }
}
