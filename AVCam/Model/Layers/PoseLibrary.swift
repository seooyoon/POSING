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

    /// 번호 순서대로 정렬한 포즈 목록. 짝이 맞지 않는 파일은 건너뜀
    static func load(bundle: Bundle = .main) -> [LayerItem] {
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
                guard let photoURL = photos[id], let photo = UIImage(contentsOfFile: photoURL.path) else { return nil }
                return LayerItem(id: id, thumbnail: photo, imageURL: lineURL)
            }
            // 파일 이름이 pose_01, pose_02 … 이므로 이름순 = 번호순
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }
}
