//
//  MYPhotoPicker.swift
//  포징
//
//  MY 사진 추가용 시스템 사진 피커 (docs/01_SPEC.md 5절).
//  여러 장 고르면 선택 순서 번호가 붙고, 오른쪽 위 추가 버튼으로 끝낸다. 취소하면 아무것도 바뀌지 않음.
//  사진 앱 읽기 권한 없이 동작한다.
//

import PhotosUI
import SwiftUI

private struct MYPhotoPicker: ViewModifier {

    @Binding var isPresented: Bool
    let layers: LayerState
    @State private var selection: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented,
                          selection: $selection,
                          maxSelectionCount: AppDefaults.allowsMultipleMYSelection ? nil : 1,
                          selectionBehavior: .ordered,
                          matching: .images,
                          // 같은 사진을 알아보기 위해 사진 식별자를 받음 (권한 필요 없음)
                          photoLibrary: .shared())
            .onChange(of: selection) { _, items in
                guard !items.isEmpty else { return }
                selection = []
                Task {
                    let added = await MYLibrary.importPhotos(items)
                    layers.addMY(added)
                }
            }
    }
}

extension View {
    /// 카메라 화면(MY 꾹 누르기)과 설정 화면(사진 추가 줄)에서 같이 씀
    func myPhotoPicker(isPresented: Binding<Bool>, layers: LayerState) -> some View {
        modifier(MYPhotoPicker(isPresented: isPresented, layers: layers))
    }
}
