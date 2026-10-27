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
    var my = LayerSlot(defaultOpacity: AppDefaults.myOpacity)
    /// 지금 열린 패널. 포즈 · MY 패널은 같은 자리에 하나만
    private(set) var openPanel: LayerKind?
    /// MY 꾹 누르기로 사진 피커를 띄움
    var isPickingMY = false
    /// 초기화 꾹 누르기로 설정 화면을 띄움
    var isShowingSettings = false

    init(poses: [LayerItem] = PoseLibrary.load(), myItems: [LayerItem] = MYLibrary.load()) {
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
        guard let first = newItems.first else { return }
        let newIDs = Set(newItems.map(\.id))
        my.items = newItems + my.items.filter { !newIDs.contains($0.id) }
        my.select(first)
        loadImage(of: first, in: .my)
        openPanel = .my
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

    /// 선택 중인 사진을 지우면 화면의 MY 레이어도 사라짐
    func deleteMY(at offsets: IndexSet) {
        let removed = offsets.map { my.items[$0] }
        if removed.contains(where: { $0.id == my.selectedID }) {
            my.deselect()
        }
        my.items.remove(atOffsets: offsets)
        MYLibrary.delete(removed)
        MYLibrary.saveOrder(my.items)
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
