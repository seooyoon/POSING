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
    /// 화면에 겹치는 이미지. 고를 때 한 번만 읽음
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
        image = UIImage(contentsOfFile: item.imageURL.path)
        opacity = defaultOpacity
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

    init(poses: [LayerItem] = PoseLibrary.load()) {
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

    func toggle(_ item: LayerItem, in kind: LayerKind) {
        self[kind].toggle(item)
    }

    /// 초기화 탭: 선택 해제 + 패널 닫기. 목록은 그대로
    func reset() {
        pose.deselect()
        my.deselect()
        openPanel = nil
    }
}
