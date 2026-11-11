//
//  CameraLook.swift
//  포징
//
//  셔터 왼쪽 카메라 버튼의 데이터 (docs/01_SPEC.md 7-1절, docs/04_ASSETS.md 3-1절).
//  앱 번들 Cameras 폴더의 `camera_XX_이름.png` + 선택 `camera_XX_이름.cube`를 읽는다.
//

import UIKit

/// 사진에 적용할 색감. LUT가 없으면 보정 없음
struct CameraLook: Equatable, Sendable {
    let id: String
    let isDefault: Bool
    let lutURL: URL?
    /// 파일이 하나도 없을 때 쓰는 기본 카메라
    static let builtInDefault = CameraLook(id: "camera_00_\(CameraLookLibrary.defaultName)", isDefault: true, lutURL: nil)
}

struct CameraLookItem: Identifiable, Equatable {
    let look: CameraLook
    /// 설정 화면에 보이는 이름 (파일 이름의 이름 부분)
    let name: String
    let image: UIImage

    var id: String { look.id }
}

enum CameraLookLibrary {

    static let defaultName = "기본"
    private static let folderName = "Cameras"
    private static let prefix = "camera_"
    /// 버튼 · 목록 칸 이미지 크기 (52pt × 3배)
    private static let imagePixels = 156

    private struct Entry {
        let look: CameraLook
        let name: String
        let imageURL: URL?
    }

    /// 설정에서 바꾼 순서를 적용한 카메라 목록. 순서에 없는 새 카메라는 번호순으로 뒤에 붙음
    static func load(bundle: Bundle = .main) -> [CameraLookItem] {
        let entries = loadEntries(bundle: bundle)
        let savedOrder = UserDefaults.standard.stringArray(forKey: SettingsKeys.cameraOrder) ?? []
        let rank = Dictionary(savedOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return entries.enumerated()
            .sorted { lhs, rhs in
                (rank[lhs.element.look.id] ?? savedOrder.count + lhs.offset) < (rank[rhs.element.look.id] ?? savedOrder.count + rhs.offset)
            }
            .map { CameraLookItem(look: $0.element.look, name: $0.element.name, image: image(for: $0.element)) }
    }

    /// 앱을 켤 때 쓸 카메라 (설정에서 고정). 없거나 파일이 사라졌으면 기본 카메라
    static func startLook(bundle: Bundle = .main) -> CameraLook {
        let looks = loadEntries(bundle: bundle).map(\.look)
        let savedID = UserDefaults.standard.string(forKey: SettingsKeys.startCamera)
        return looks.first { $0.id == savedID } ?? looks.first(where: \.isDefault) ?? .builtInDefault
    }

    static func saveOrder(_ items: [CameraLookItem]) {
        UserDefaults.standard.set(items.map(\.id), forKey: SettingsKeys.cameraOrder)
    }

    static func saveStartLook(_ look: CameraLook) {
        UserDefaults.standard.set(look.id, forKey: SettingsKeys.startCamera)
    }

    /// 번호 순서대로 정렬한 카메라. 기본 카메라는 파일이 없어도 항상 맨 앞에 있음
    private static func loadEntries(bundle: Bundle) -> [Entry] {
        let files = bundle.url(forResource: folderName, withExtension: nil).flatMap {
            try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        } ?? []
        let luts = Dictionary(
            files.filter { $0.pathExtension.lowercased() == "cube" }.map { (fileStem($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let entries = files
            .filter { $0.pathExtension.lowercased() == "png" && fileStem($0).hasPrefix(prefix) }
            .map { url -> Entry in
                let id = fileStem(url)
                // camera_01_기본 → 기본
                let name = id.split(separator: "_", maxSplits: 2).last.map(String.init) ?? id
                let isDefault = name == defaultName
                // 기본 카메라는 보정 없음
                return Entry(look: CameraLook(id: id, isDefault: isDefault, lutURL: isDefault ? nil : luts[id]),
                             name: name, imageURL: url)
            }
            .sorted { $0.look.id.localizedStandardCompare($1.look.id) == .orderedAscending }
        guard entries.contains(where: \.look.isDefault) else {
            return [Entry(look: .builtInDefault, name: defaultName, imageURL: nil)] + entries
        }
        return entries
    }

    /// 파일 이름의 한글이 기기마다 다르게 조합되어도 같은 글자로 비교되게 맞춤
    private static func fileStem(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
    }

    private static func image(for entry: Entry) -> UIImage {
        entry.imageURL.flatMap { ImageDownsampler.image(at: $0, maxPixels: imagePixels) }
            ?? UIImage(systemName: "camera.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
            ?? UIImage()
    }
}

/// 카메라 목록, 지금 고른 카메라, 앱을 켤 때 쓸 카메라
@MainActor
@Observable
final class CameraLookState {

    private(set) var items: [CameraLookItem]
    /// 화면에서 고른 카메라 (저장하지 않음)
    private(set) var selectedID: String
    /// 시작 카메라 (설정에서 고정, 저장)
    private(set) var startID: String

    init(items: [CameraLookItem] = CameraLookLibrary.load(), start: CameraLook = CameraLookLibrary.startLook()) {
        self.items = items
        selectedID = start.id
        startID = start.id
    }

    var selected: CameraLookItem? {
        items.first { $0.id == selectedID } ?? items.first
    }

    /// 카메라 목록에 보이는 카메라: 지금 고른 카메라는 버튼에 있으므로 뺌
    var listItems: [CameraLookItem] {
        items.filter { $0.id != selected?.id }
    }

    func select(_ item: CameraLookItem) {
        selectedID = item.id
    }

    var startItem: CameraLookItem? {
        items.first { $0.id == startID } ?? items.first
    }

    /// 설정에서 시작 카메라를 고름. 다음에 앱을 켤 때부터 적용 (지금 화면의 카메라는 그대로)
    func setStart(_ item: CameraLookItem) {
        startID = item.id
        CameraLookLibrary.saveStartLook(item.look)
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        CameraLookLibrary.saveOrder(items)
    }
}
