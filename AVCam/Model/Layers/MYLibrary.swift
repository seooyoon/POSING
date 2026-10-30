//
//  MYLibrary.swift
//  포징
//
//  MY 목록 저장소 (docs/01_SPEC.md 5절). 고른 사진을 앱 Documents/MY 폴더에 복사하고,
//  목록 순서를 my_order.json에 저장한다. 원본을 사진 앱에서 지워도 목록은 남는다.
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

    // MARK: - 불러오기 · 저장

    /// 저장된 순서대로 MY 목록. 파일이 없어진 칸은 건너뜀
    static func load() -> [LayerItem] {
        guard let data = try? Data(contentsOf: orderFile),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return names.compactMap { item(named: $0) }
    }

    static func saveOrder(_ items: [LayerItem]) {
        guard let data = try? JSONEncoder().encode(items.map(\.id)) else { return }
        try? data.write(to: orderFile, options: .atomic)
    }

    /// 목록에서 지운 사진의 복사본 삭제
    static func delete(_ items: [LayerItem]) {
        for item in items {
            try? FileManager.default.removeItem(at: item.imageURL)
        }
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
            guard let jpeg = downsampledJPEG(from: data) else { continue }
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
    private static func downsampledJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = ImageDownsampler.cgImage(from: source, maxPixels: maxImagePixels)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
