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
    /// 형식 버튼 (사진): 포맷 · 해상도
    case format
    /// 형식 버튼 (비디오): 해상도 · 프레임률
    case videoFormat
}

struct QuickSettingsOption: Identifiable {
    let id: String
    let title: String
    /// 작은 위첨자 (예: MP)
    var superscript: String?
    let isSelected: Bool
    var isEnabled = true
    /// 기본값. 앞에 점이 붙음 (선택과 별개, 색은 글자를 따라감)
    var isDefault = false
    let action: () -> Void
}

struct QuickSettingsRow: Identifiable {
    let title: String
    let options: [QuickSettingsOption]
    /// 앞에서 비울 칸 수 (LIVE 켬 · 끔을 플래시 켬 · 끔과 같은 칸에)
    var startColumn = 0
    var id: String { title }
}

struct QuickSettingsPanel: View {

    let rows: [QuickSettingsRow]
    /// 판 아래 작은 안내
    var footnote: String?
    /// 어두운 장면이면 유리를 더 어둡게
    var isSceneDark = false

    // 기본 카메라 화면에서 잰 값
    private let titleInset: CGFloat = 20
    private let titleWidth: CGFloat = 93
    private let columnWidth: CGFloat = 87
    private let rowHeight: CGFloat = 34
    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    Text(row.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: titleWidth, alignment: .leading)
                    Color.clear
                        .frame(width: columnWidth * CGFloat(row.startColumn), height: 0)
                    ForEach(row.options) { option in
                        optionButton(option)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: rowHeight)
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(height: 19)
                    .padding(.bottom, 5)
            }
        }
        .padding(.leading, titleInset)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.white.opacity(isSceneDark ? 0.03 : 0.1)), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
        }
    }

    private func optionButton(_ option: QuickSettingsOption) -> some View {
        Button(action: option.action) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(option.title)
                    .font(.cameraDigits(size: 14.5))
                if let superscript = option.superscript {
                    Text(superscript)
                        .font(.system(size: 8.5))
                        .baselineOffset(5)
                }
            }
            // 기본값 점은 글자 왼쪽 바깥에 걸침 (글자 시작은 칸마다 그대로)
            .overlay(alignment: .leading) {
                if option.isDefault {
                    Circle()
                        .fill(option.isSelected ? Color.cameraYellow : .white)
                        .frame(width: 5.5, height: 5.5)
                        .offset(x: -9.5)
                }
            }
            .foregroundStyle(option.isSelected ? Color.cameraYellow : .white)
            .opacity(option.isEnabled ? 1 : 0.35)
            .frame(width: columnWidth, height: rowHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!option.isEnabled)
    }
}

#Preview {
    QuickSettingsPanel(rows: [
        QuickSettingsRow(title: "포맷", options: [
            QuickSettingsOption(id: "jpeg", title: "JPEG", isSelected: true, isDefault: true) {},
            QuickSettingsOption(id: "raw", title: "RAW", isSelected: false) {},
        ]),
        QuickSettingsRow(title: "해상도", options: [
            QuickSettingsOption(id: "24", title: "24", superscript: "MP", isSelected: true, isDefault: true) {},
            QuickSettingsOption(id: "48", title: "48", superscript: "MP", isSelected: false) {},
        ]),
    ], footnote: "최대 24MP의 해상도입니다.")
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
            QuickSettingsPanel(rows: flashAndLiveRows, isSceneDark: camera.isSceneDark)
        case .format:
            QuickSettingsPanel(rows: formatRows,
                               footnote: "최대 \(camera.activeResolution)MP의 해상도입니다.",
                               isSceneDark: camera.isSceneDark)
        case .videoFormat:
            QuickSettingsPanel(rows: videoFormatRows, isSceneDark: camera.isSceneDark)
        }
    }

    /// 비디오는 조명으로 쓰는 플래시만 (전면은 조명이 없어 비어 있음). LIVE '자동'은 만들 수 없어서 켬 · 끔만
    private var flashAndLiveRows: [QuickSettingsRow] {
        var rows: [QuickSettingsRow] = []
        if !(camera.captureMode.isMovie && camera.zoom.isFrontCamera) {
            rows.append(QuickSettingsRow(title: "플래시", options: FlashMode.allCases.map { mode in
                QuickSettingsOption(id: mode.rawValue, title: mode.title, isSelected: camera.flashMode == mode) {
                    camera.flashMode = mode
                }
            }))
        }
        if camera.captureMode == .photo {
            // 비율이 4:3이 아니거나 RAW면 LIVE를 켤 수 없음. 48MP에서 켜면 24MP로 바뀜
            rows.append(QuickSettingsRow(title: "LIVE", options: [
                QuickSettingsOption(id: "on", title: "켬", isSelected: camera.isLivePhotoActive,
                                    isEnabled: camera.isLivePhotoAvailable) {
                    camera.isLivePhotoEnabled = true
                },
                QuickSettingsOption(id: "off", title: "끔", isSelected: !camera.isLivePhotoActive) {
                    camera.isLivePhotoEnabled = false
                },
            ], startColumn: 1))
        }
        return rows
    }

    private var videoFormatRows: [QuickSettingsRow] {
        // 슬로 모션은 HD 고정이라 프레임률만
        if camera.captureMode == .slowMotion {
            return [QuickSettingsRow(title: "프레임률", options: VideoMode.slowMotionFrameRates.map { rate in
                QuickSettingsOption(id: "\(rate)", title: "\(rate)", isSelected: camera.activeSlowMotionFrameRate == rate,
                                    isEnabled: camera.isVideoModeAvailable(VideoMode(resolution: .hd, frameRate: rate)),
                                    isDefault: rate == AppDefaults.slowMotionFrameRate) {
                    camera.slowMotionFrameRate = rate
                }
            })]
        }
        let mode = camera.activeVideoMode
        return [
            QuickSettingsRow(title: "해상도", options: VideoResolution.allCases.map { resolution in
                QuickSettingsOption(id: resolution.rawValue, title: resolution.label, isSelected: mode.resolution == resolution,
                                    isEnabled: camera.isVideoModeAvailable(VideoMode(resolution: resolution, frameRate: mode.frameRate)),
                                    isDefault: resolution == AppDefaults.videoResolution) {
                    camera.videoMode.resolution = resolution
                }
            }),
            QuickSettingsRow(title: "프레임률", options: VideoMode.frameRates.map { rate in
                QuickSettingsOption(id: "\(rate)", title: "\(rate)", isSelected: mode.frameRate == rate,
                                    isEnabled: camera.isVideoModeAvailable(VideoMode(resolution: mode.resolution, frameRate: rate)),
                                    isDefault: rate == AppDefaults.videoFrameRate) {
                    camera.videoMode.frameRate = rate
                }
            }),
        ]
    }

    private var formatRows: [QuickSettingsRow] {
        [
            QuickSettingsRow(title: "포맷", options: PhotoCodec.allCases.map { codec in
                QuickSettingsOption(id: codec.rawValue, title: codec.label, isSelected: camera.activeCodec == codec,
                                    isEnabled: codec != .raw || camera.isRAWSupported,
                                    isDefault: codec == AppDefaults.photoCodec) {
                    camera.photoCodec = codec
                }
            }),
            QuickSettingsRow(title: "해상도", options: camera.availableResolutions.map { resolution in
                QuickSettingsOption(id: "\(resolution)", title: "\(resolution)", superscript: "MP",
                                    isSelected: camera.activeResolution == resolution,
                                    isDefault: resolution == PhotoResolution.defaultValue(for: camera.activeCodec)) {
                    camera.photoResolution = resolution
                }
            }),
        ]
    }
}
