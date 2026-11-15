//
//  MYPhotoPicker.swift
//  포징
//
//  MY 패키지에 사진을 추가하는 시스템 사진 피커 (docs/01_SPEC.md 5절).
//  여러 장 고르면 선택 순서 번호가 붙고, 오른쪽 위 추가 버튼으로 끝낸다. 취소하면 아무것도 바뀌지 않음.
//  사진 앱 읽기 권한 없이 동작한다.
//

import PhotosUI
import SwiftUI

private struct MYPhotoPicker: ViewModifier {

    /// 사진을 추가할 패키지. 값이 있으면 피커가 뜸
    @Binding var packageID: String?
    let layers: LayerState
    @State private var selection: [PhotosPickerItem] = []
    /// 피커를 닫으면 packageID가 비므로 따로 기억
    @State private var targetID: String?

    private var isPresented: Binding<Bool> {
        Binding {
            packageID != nil
        } set: { isShown in
            if !isShown { packageID = nil }
        }
    }

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: isPresented,
                          selection: $selection,
                          maxSelectionCount: AppDefaults.allowsMultipleMYSelection ? nil : 1,
                          selectionBehavior: .ordered,
                          matching: .images,
                          // 같은 사진을 알아보기 위해 사진 식별자를 받음 (권한 필요 없음)
                          photoLibrary: .shared())
            .onChange(of: packageID) { _, id in
                if let id { targetID = id }
            }
            .onChange(of: selection) { _, items in
                guard !items.isEmpty, let id = targetID, let package = layers.myPackage(id) else { return }
                selection = []
                Task {
                    let added = await package.library.importPhotos(items)
                    layers.addMY(added, to: id)
                }
            }
    }
}

extension View {
    /// 카메라 화면(대표 이미지 꾹 누르기)과 설정 화면(사진 추가 줄)에서 같이 씀
    func myPhotoPicker(packageID: Binding<String?>, layers: LayerState) -> some View {
        modifier(MYPhotoPicker(packageID: packageID, layers: layers))
    }
}
