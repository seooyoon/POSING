//
//  MYLibrary.swift
//  포징
//
//  MY 저장소 (docs/01_SPEC.md 5 · 6절). 앱에 넣어 둔 MY 패키지와 패키지마다 직접 추가한 사진.
//  추가한 사진은 앱 Documents/MY/<패키지 이름>/ 폴더에 복사한다. 같은 폴더에
//  order.json(넣어 둔 사진 + 추가한 사진 순서), names.json(이름), hidden.json(지운 넣어 둔 사진)을 저장한다.
//  앱 번들 사진은 지울 수 없어 숨김 목록으로만 뺀다. 원본을 사진 앱에서 지워도 추가한 사진은 남는다.
//

import ImageIO
import PhotosUI
import SwiftUI

/// 패키지 하나의 사진 순서 · 이름 · 추가한 사진 저장소. 폴더 번호가 바뀌어도 이어지게 패키지 이름으로 나눔
struct MYLibrary {

    /// 화면에 겹칠 사진의 긴 변 최대 크기 (메모리 절약)
    private static let maxImagePixels = 2400

    /// 이름 최대 글자 수 (띄어쓰기 포함)
    static let maxNameLength = 10

    /// 저장 키 앞머리: 넣어 둔 사진 `bundle/01.jpg`, 추가한 사진 `added/파일 이름`
    private static let bundlePrefix = "bundle/"
    private static let addedPrefix = "added/"
    /// 추가한 사진 id 앞머리 (넣어 둔 사진 id `01_셀카/01.jpg`와 겹치지 않게)
    private static let addedIDPrefix = "추가/"

    let packageName: String

    private var folder: URL {
        URL.documentsDirectory.appending(path: "MY", directoryHint: .isDirectory)
            .appending(path: packageName, directoryHint: .isDirectory)
    }

    private var orderFile: URL { folder.appending(path: "order.json") }
    private var namesFile: URL { folder.appending(path: "names.json") }
    private var hiddenFile: URL { folder.appending(path: "hidden.json") }

    static func isAdded(_ item: LayerItem) -> Bool {
        item.id.hasPrefix(addedIDPrefix)
    }

    // MARK: - 불러오기

    /// 저장된 순서대로 패키지 사진. 순서에 없는 넣어 둔 사진(새로 넣은 것)은 뒤에 번호순,
    /// 지운 넣어 둔 사진 · 파일이 없어진 추가한 사진은 빠짐
    func load(bundled: [LayerItem]) -> [LayerItem] {
        let hidden = Set(loadHidden())
        let bundledByKey = Dictionary(uniqueKeysWithValues: bundled.map { (key(of: $0), $0) })
        var items = loadOrder().compactMap { key -> LayerItem? in
            if key.hasPrefix(Self.bundlePrefix) {
                return hidden.contains(key) ? nil : bundledByKey[key]
            }
            // 예전 저장본은 추가한 사진 파일 이름만 있음
            let name = key.hasPrefix(Self.addedPrefix) ? String(key.dropFirst(Self.addedPrefix.count)) : key
            return item(named: name)
        }
        let listed = Set(items.map(key(of:)))
        items += bundled.filter { !listed.contains(key(of: $0)) && !hidden.contains(key(of: $0)) }
        let names = loadNames()
        return items.map { item in
            var item = item
            // 예전 저장본은 추가한 사진의 파일 이름을 키로 저장함
            let legacyKey = Self.isAdded(item) ? item.imageURL.lastPathComponent : nil
            item.name = names[key(of: item)] ?? legacyKey.flatMap { names[$0] } ?? ""
            return item
        }
    }

    /// 지운 넣어 둔 사진 수 (되돌리기 버튼)
    func hiddenCount() -> Int {
        loadHidden().count
    }

    // MARK: - 저장

    func saveOrder(_ items: [LayerItem]) {
        write(items.map(key(of:)), to: orderFile)
    }

    /// 이름이 있는 칸만 저장 (저장 키 → 이름). 지운(숨긴) 넣어 둔 사진의 이름은 되돌릴 때를 위해 남김
    func saveNames(_ items: [LayerItem]) {
        let hidden = Set(loadHidden())
        var names = loadNames().filter { hidden.contains($0.key) }
        for item in items where !item.name.isEmpty {
            names[key(of: item)] = item.name
        }
        write(names, to: namesFile)
    }

    /// 추가한 사진은 복사본 삭제, 넣어 둔 사진은 숨김 목록에 넣음
    func delete(_ items: [LayerItem]) {
        var hidden = loadHidden()
        for item in items {
            if Self.isAdded(item) {
                try? FileManager.default.removeItem(at: item.imageURL)
            } else if !hidden.contains(key(of: item)) {
                hidden.append(key(of: item))
            }
        }
        write(hidden, to: hiddenFile)
    }

    /// 지운 넣어 둔 사진을 모두 다시 보이게 (순서 목록 맨 뒤로)
    func restoreHidden() {
        try? FileManager.default.removeItem(at: hiddenFile)
    }

    // MARK: - 파일

    private func key(of item: LayerItem) -> String {
        (Self.isAdded(item) ? Self.addedPrefix : Self.bundlePrefix) + item.imageURL.lastPathComponent
    }

    private func loadOrder() -> [String] { read([String].self, from: orderFile) ?? [] }
    private func loadHidden() -> [String] { read([String].self, from: hiddenFile) ?? [] }
    private func loadNames() -> [String: String] { read([String: String].self, from: namesFile) ?? [:] }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        // 없는 파일을 읽으면 Xcode에 오류 기록이 남음
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - 사진 추가

    /// 피커에서 고른 순서대로 사진을 복사해 목록 칸으로 만든다.
    /// 같은 사진은 같은 파일 이름이 되어, 다시 추가하면 기존 칸으로 합쳐짐.
    /// 기기에 없는 아이클라우드 사진처럼 읽지 못한 사진은 건너뜀
    func importPhotos(_ pickerItems: [PhotosPickerItem]) async -> [LayerItem] {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var items: [LayerItem] = []
        for pickerItem in pickerItems {
            guard let data = try? await pickerItem.loadTransferable(type: Data.self) else { continue }
            let name = Self.fileName(for: pickerItem.itemIdentifier)
            guard let jpeg = Self.downsampledJPEG(from: data, maxPixels: Self.maxImagePixels) else { continue }
            let url = folder.appending(path: name)
            guard (try? jpeg.write(to: url, options: .atomic)) != nil,
                  let item = item(named: name)
            else { continue }
            items.append(item)
        }
        return items
    }

    // MARK: - 내부

    /// id는 `추가/패키지 이름/파일 이름`
    private func item(named name: String) -> LayerItem? {
        let url = folder.appending(path: name)
        guard let thumbnail = ImageDownsampler.image(at: url, maxPixels: ImageDownsampler.thumbnailPixels) else { return nil }
        return LayerItem(id: "\(Self.addedIDPrefix)\(packageName)/\(name)", thumbnail: thumbnail, imageURL: url)
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

/// 앱에 넣어 둔 MY 사진 묶음 하나 (docs/04_ASSETS.md 1-1절).
/// 넣어 둔 사진 + 대표 이미지를 꾹 눌러 추가한 사진. 순서 · 삭제는 설정에서 바꿈
struct MYPackage: Identifiable {
    /// 폴더 이름 (`01_셀카`)
    let id: String
    /// 목록에 보이는 이름 (`셀카`)
    let name: String
    let cover: UIImage
    /// 앱에 넣어 둔 사진 전체 (파일 번호순, 지운 것 포함)
    let bundledItems: [LayerItem]
    /// 지금 보이는 사진 (저장된 순서)
    var items: [LayerItem]

    var library: MYLibrary { MYLibrary(packageName: name) }
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
        return MYPackage(id: id, name: name, cover: cover, bundledItems: items,
                         items: MYLibrary(packageName: name).load(bundled: items))
    }
}
