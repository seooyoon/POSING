//
//  PoseLibrary.swift
//  포징
//
//  앱 번들의 Poses 폴더에서 `pose_XX_이름_photo` + `pose_XX_이름_line.png` 쌍을 읽는다 (docs/04_ASSETS.md 1절).
//

import UIKit

enum PoseLibrary {

    private static let folderName = "Poses"
    private static let photoSuffix = "_photo"
    private static let lineSuffix = "_line"

    /// 설정에서 바꾼 순서를 적용한 포즈 목록. 순서에 없는 새 포즈는 번호순으로 뒤에 붙음
    static func load(bundle: Bundle = .main) -> [LayerItem] {
        let items = loadInNumberOrder(bundle: bundle)
        let savedOrder = UserDefaults.standard.stringArray(forKey: SettingsKeys.poseOrder) ?? []
        let rank = Dictionary(savedOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.enumerated()
            .sorted { lhs, rhs in
                (rank[lhs.element.id] ?? savedOrder.count + lhs.offset) < (rank[rhs.element.id] ?? savedOrder.count + rhs.offset)
            }
            .map(\.element)
    }

    static func saveOrder(_ items: [LayerItem]) {
        UserDefaults.standard.set(items.map(\.id), forKey: SettingsKeys.poseOrder)
    }

    /// 번호 순서대로 정렬한 포즈 목록. 짝이 맞지 않는 파일은 건너뜀
    private static func loadInNumberOrder(bundle: Bundle) -> [LayerItem] {
        guard let folder = bundle.url(forResource: folderName, withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }

        let photos = Dictionary(
            files.compactMap { url -> (String, URL)? in
                let name = url.deletingPathExtension().lastPathComponent
                guard name.hasSuffix(photoSuffix) else { return nil }
                return (String(name.dropLast(photoSuffix.count)), url)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return files
            .filter { $0.pathExtension.lowercased() == "png" }
            .compactMap { lineURL -> LayerItem? in
                let name = lineURL.deletingPathExtension().lastPathComponent
                guard name.hasSuffix(lineSuffix) else { return nil }
                let id = String(name.dropLast(lineSuffix.count))
                guard let photoURL = photos[id], let photo = ImageDownsampler.image(at: photoURL, maxPixels: ImageDownsampler.thumbnailPixels) else { return nil }
                return LayerItem(id: id, thumbnail: photo, imageURL: lineURL)
            }
            // 파일 이름이 pose_01, pose_02 … 이므로 이름순 = 번호순
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }
}
