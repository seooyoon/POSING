//
//  LayerItem.swift
//  포징
//
//  포즈 · MY 목록의 칸 하나. 목록에는 썸네일을, 고르면 imageURL의 이미지를 화면에 겹친다.
//

import UIKit

/// 레이어 종류. 화면에서는 항상 MY가 아래, 포즈가 위
enum LayerKind: CaseIterable {
    case pose
    case my
}

struct LayerItem: Identifiable, Equatable {
    /// 포즈는 파일 이름(`pose_01_이름`), MY는 저장된 파일 이름
    let id: String
    /// 목록 칸에 보이는 이미지 (포즈 대표 사진, MY 사진 축소본)
    let thumbnail: UIImage
    /// 화면에 겹칠 이미지 (포즈 테두리 PNG, MY 원본 사진)
    let imageURL: URL
}

