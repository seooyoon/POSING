//
//  QuickSettingsPanel.swift
//  포징
//
//  상단 빠른 설정 판 (기본 카메라 모양): 상단 바 위로 내려오는 반투명 판에 `이름 | 값 값 값` 줄.
//  오른쪽 묶음 꾹 누르기 → 플래시 · LIVE, 형식 버튼 탭 · 꾹 누르기 → 포맷 · 해상도 (docs/02_UI.md 2절).
//  선택값은 노란색, 바깥을 탭하면 닫힘 (CameraUI).
//

import SwiftUI

/// 지금 열린 빠른 설정 판
enum QuickSettingsKind {
    /// 오른쪽 묶음 꾹 누르기: 플래시 · LIVE
    case flashAndLive
    /// 형식 버튼: 포맷 · 해상도
    case format
}

struct QuickSettingsOption: Identifiable {
    let id: String
    let title: String
    /// 작은 위첨자 (예: MP)
    var superscript: String?
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void
}

struct QuickSettingsRow: Identifiable {
    let title: String
    let options: [QuickSettingsOption]
    var id: String { title }
}

struct QuickSettingsPanel: View {

    let rows: [QuickSettingsRow]
    /// 선택값 앞에 노란 점 (포맷 · 해상도 판)
    var showsDots = false
    /// 판 아래 작은 안내
    var footnote: String?

    private let titleWidth: CGFloat = 66
    private let columnWidth: CGFloat = 86

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    Text(row.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: titleWidth, alignment: .leading)
                    ForEach(row.options) { option in
                        optionButton(option)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 50)
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: .rect(cornerRadius: 34, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 34, style: .continuous))
    }

    private func optionButton(_ option: QuickSettingsOption) -> some View {
        Button(action: option.action) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if showsDots && option.isSelected {
                    Circle()
                        .fill(Color.cameraYellow)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 5 }
                        .padding(.trailing, 6)
                }
                Text(option.title)
                    .font(.system(size: 19))
                if let superscript = option.superscript {
                    Text(superscript)
                        .font(.system(size: 11))
                        .baselineOffset(8)
                }
            }
            .foregroundStyle(option.isSelected ? Color.cameraYellow : .white)
            .opacity(option.isEnabled ? 1 : 0.35)
            .frame(width: columnWidth, height: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!option.isEnabled)
    }
}

#Preview {
    QuickSettingsPanel(rows: [
        QuickSettingsRow(title: "포맷", options: [
            QuickSettingsOption(id: "heif", title: "HEIF", isSelected: false) {},
            QuickSettingsOption(id: "jpeg", title: "JPEG", isSelected: true) {},
        ]),
        QuickSettingsRow(title: "해상도", options: [
            QuickSettingsOption(id: "24", title: "24", superscript: "MP", isSelected: true) {},
            QuickSettingsOption(id: "48", title: "48", superscript: "MP", isSelected: false) {},
        ]),
    ], showsDots: true, footnote: "최대 24MP의 해상도입니다.")
    .padding()
    .background(.gray)
}

/// 카메라 값으로 빠른 설정 판 줄을 만든다
struct QuickSettingsView<CameraModel: Camera>: View {

    @State var camera: CameraModel
    let kind: QuickSettingsKind

    var body: some View {
        switch kind {
        case .flashAndLive:
            QuickSettingsPanel(rows: flashAndLiveRows)
        case .format:
            QuickSettingsPanel(rows: formatRows, showsDots: true,
                               footnote: "최대 \(camera.activeResolution)MP의 해상도입니다.")
        }
    }

    /// 비디오는 조명으로 쓰는 플래시만 (전면은 조명이 없어 비어 있음). LIVE '자동'은 만들 수 없어서 켬 · 끔만
    private var flashAndLiveRows: [QuickSettingsRow] {
        var rows: [QuickSettingsRow] = []
        if !(camera.captureMode == .video && camera.zoom.isFrontCamera) {
            rows.append(QuickSettingsRow(title: "플래시", options: FlashMode.allCases.map { mode in
                QuickSettingsOption(id: mode.rawValue, title: mode.title, isSelected: camera.flashMode == mode) {
                    camera.flashMode = mode
                }
            }))
        }
        if camera.captureMode == .photo {
            // 비율이 4:3이 아니거나 48MP면 LIVE를 켤 수 없음
            rows.append(QuickSettingsRow(title: "LIVE", options: [
                QuickSettingsOption(id: "on", title: "켬", isSelected: camera.isLivePhotoActive,
                                    isEnabled: camera.isLivePhotoAvailable) {
                    camera.isLivePhotoEnabled = true
                },
                QuickSettingsOption(id: "off", title: "끔", isSelected: !camera.isLivePhotoActive) {
                    camera.isLivePhotoEnabled = false
                },
            ]))
        }
        return rows
    }

    private var formatRows: [QuickSettingsRow] {
        [
            QuickSettingsRow(title: "포맷", options: PhotoCodec.allCases.map { codec in
                QuickSettingsOption(id: codec.rawValue, title: codec.label, isSelected: camera.photoCodec == codec) {
                    camera.photoCodec = codec
                }
            }),
            QuickSettingsRow(title: "해상도", options: camera.availableResolutions.map { resolution in
                QuickSettingsOption(id: "\(resolution)", title: "\(resolution)", superscript: "MP",
                                    isSelected: camera.activeResolution == resolution) {
                    camera.photoResolution = resolution
                }
            }),
        ]
    }
}
