//
//  MYLibrary.swift
//  포징
//
//  MY 저장소 (docs/01_SPEC.md 5절). 앱에 넣어 둔 MY 패키지와 '내 사진' 패키지.
//  '내 사진'은 고른 사진을 앱 Documents/MY 폴더에 복사하고,
//  목록 순서를 my_order.json, 이름을 my_names.json에 저장한다. 원본을 사진 앱에서 지워도 목록은 남는다.
//

import ImageIO
import PhotosUI
import SwiftUI

enum MYLibrary {

    /// 화면에 겹칠 사진의 긴 변 최대 크기 (메모리 절약)
    private static let maxImagePixels = 2400

    private static var folder: URL {
        URL.documentsDirectory.appending(path: "MY", directoryHint: .isDirectory)
    }

    private static var orderFile: URL {
        URL.documentsDirectory.appending(path: "my_order.json")
    }

    private static var namesFile: URL {
        URL.documentsDirectory.appending(path: "my_names.json")
    }

    /// '내 사진' 패키지 대표 이미지 (설정에서 고른 사진). 없으면 첫 사진
    private static var coverFile: URL {
        URL.documentsDirectory.appending(path: "my_cover.jpg")
    }
    /// 대표 이미지는 작게만 보이므로 긴 변을 줄여 저장
    private static let maxCoverPixels = 600

    /// 이름 최대 글자 수 (띄어쓰기 포함)
    static let maxNameLength = 10

    // MARK: - 불러오기 · 저장

    /// 저장된 순서대로 MY 목록. 파일이 없어진 칸은 건너뜀
    static func load() -> [LayerItem] {
        guard let data = try? Data(contentsOf: orderFile),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        let itemNames = loadNames()
        return names.compactMap { name in
            var item = item(named: name)
            item?.name = itemNames[name] ?? ""
            return item
        }
    }

    static func saveOrder(_ items: [LayerItem]) {
        guard let data = try? JSONEncoder().encode(items.map(\.id)) else { return }
        try? data.write(to: orderFile, options: .atomic)
    }

    /// 이름이 있는 칸만 저장 (파일 이름 → 이름)
    static func saveNames(_ items: [LayerItem]) {
        let names = Dictionary(uniqueKeysWithValues: items.filter { !$0.name.isEmpty }.map { ($0.id, $0.name) })
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? data.write(to: namesFile, options: .atomic)
    }

    private static func loadNames() -> [String: String] {
        guard let data = try? Data(contentsOf: namesFile),
              let names = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return names
    }

    /// 목록에서 지운 사진의 복사본 삭제
    static func delete(_ items: [LayerItem]) {
        for item in items {
            try? FileManager.default.removeItem(at: item.imageURL)
        }
    }

    // MARK: - 내 사진 대표 이미지

    static func loadCover() -> UIImage? {
        ImageDownsampler.image(at: coverFile, maxPixels: ImageDownsampler.thumbnailPixels)
    }

    /// 사진 앱에서 고른 사진을 대표 이미지로 저장. 읽지 못하면 nil
    static func saveCover(_ pickerItem: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let jpeg = downsampledJPEG(from: data, maxPixels: maxCoverPixels),
              (try? jpeg.write(to: coverFile, options: .atomic)) != nil
        else { return nil }
        return loadCover()
    }

    /// 대표 이미지를 지워 첫 사진으로 되돌림
    static func deleteCover() {
        try? FileManager.default.removeItem(at: coverFile)
    }

    // MARK: - 사진 추가

    /// 피커에서 고른 순서대로 사진을 복사해 목록 칸으로 만든다.
    /// 같은 사진은 같은 파일 이름이 되어, 다시 추가하면 기존 칸으로 합쳐짐.
    /// 기기에 없는 아이클라우드 사진처럼 읽지 못한 사진은 건너뜀
    static func importPhotos(_ pickerItems: [PhotosPickerItem]) async -> [LayerItem] {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var items: [LayerItem] = []
        for pickerItem in pickerItems {
            guard let data = try? await pickerItem.loadTransferable(type: Data.self) else { continue }
            let name = fileName(for: pickerItem.itemIdentifier)
            guard let jpeg = downsampledJPEG(from: data, maxPixels: maxImagePixels) else { continue }
            let url = folder.appending(path: name)
            guard (try? jpeg.write(to: url, options: .atomic)) != nil,
                  let item = item(named: name)
            else { continue }
            items.append(item)
        }
        return items
    }

    // MARK: - 내부

    private static func item(named name: String) -> LayerItem? {
        let url = folder.appending(path: name)
        guard let thumbnail = ImageDownsampler.image(at: url, maxPixels: ImageDownsampler.thumbnailPixels) else { return nil }
        return LayerItem(id: name, thumbnail: thumbnail, imageURL: url)
    }

    /// 사진 앱 식별자로 파일 이름을 만든다. 식별자가 없으면 새 이름
    private static func fileName(for identifier: String?) -> String {
        let base = identifier.map { $0.replacingOccurrences(of: "/", with: "_") } ?? UUID().uuidString
        return base + ".jpg"
    }

    /// 방향을 바로잡고 긴 변을 줄인 JPEG
    private static func downsampledJPEG(from data: Data, maxPixels: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = ImageDownsampler.cgImage(from: source, maxPixels: maxPixels)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

// MARK: - MY 패키지

/// 앱에 넣어 둔 MY 사진 묶음 하나 (docs/04_ASSETS.md 1-1절). 사진 순서는 파일 번호순 고정
struct MYPackage: Identifiable {
    /// 폴더 이름 (`01_서윤 사진`)
    let id: String
    /// 목록에 보이는 이름 (`서윤 사진`)
    let name: String
    let cover: UIImage?
    let items: [LayerItem]
}

/// 앱 번들 `MYPackages/번호_이름/` 폴더들을 읽는다. 폴더마다 `cover.jpg`(대표 이미지) + `01.jpg` `02.jpg` …
enum MYPackageLibrary {

    private static let folderName = "MYPackages"
    private static let coverName = "cover"
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    /// 폴더 번호순 패키지 목록. 사진이 하나도 없는 폴더는 건너뜀
    static func load(bundle: Bundle = .main) -> [MYPackage] {
        guard let root = bundle.url(forResource: folderName, withExtension: nil),
              let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
        else { return [] }
        return folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap(package(at:))
    }

    private static func package(at folder: URL) -> MYPackage? {
        let id = folder.lastPathComponent
        // 01_서윤 사진 → 서윤 사진
        let name = id.split(separator: "_", maxSplits: 1).last.map(String.init) ?? id
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let coverURL = files.first { $0.deletingPathExtension().lastPathComponent.lowercased() == coverName }
        let items = files.filter { $0 != coverURL }.compactMap { url -> LayerItem? in
            guard let thumbnail = ImageDownsampler.image(at: url, maxPixels: ImageDownsampler.thumbnailPixels) else { return nil }
            // 패키지가 달라도 겹치지 않게 폴더 이름을 붙임
            return LayerItem(id: "\(id)/\(url.lastPathComponent)", thumbnail: thumbnail, imageURL: url)
        }
        guard !items.isEmpty else { return nil }
        // 대표 이미지가 없으면 첫 사진으로
        let cover = coverURL.flatMap { ImageDownsampler.image(at: $0, maxPixels: ImageDownsampler.thumbnailPixels) } ?? items[0].thumbnail
        return MYPackage(id: id, name: name, cover: cover, items: items)
    }
}
