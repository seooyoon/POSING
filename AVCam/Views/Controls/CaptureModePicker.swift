//
//  CaptureModePicker.swift
//  포징
//
//  하단 가운데 `비디오 | 사진` 캡슐. 선택된 모드는 밝은 판 안에 노란 글씨 (docs/02_UI.md 7절).
//  모드 줄(타임랩스 · 슬로 모션)은 5단계에서 만든다.
//

import SwiftUI

struct CaptureModePicker<CameraModel: Camera>: View {

    /// 화면에 보이는 순서. 기본 카메라처럼 사진이 오른쪽
    static var displayOrder: [CaptureMode] { [.video, .photo] }

    /// 미리보기를 좌우로 밀었을 때 바뀔 모드. 끝에서 더 밀면 그대로
    static func mode(after mode: CaptureMode, swipe direction: SwipeDirection) -> CaptureMode {
        let order = displayOrder
        guard let index = order.firstIndex(of: mode) else { return mode }
        // 오른쪽으로 밀면 왼쪽 모드, 왼쪽으로 밀면 오른쪽 모드
        let next = direction == .right ? index - 1 : index + 1
        return order.indices.contains(next) ? order[next] : mode
    }

    @State var camera: CameraModel

    private let segmentSize = CGSize(width: 78, height: 40)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.displayOrder) { mode in
                segment(for: mode)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .animation(.easeInOut(duration: 0.2), value: camera.captureMode)
        .disabled(camera.captureActivity.isRecording)
        // 녹화 중에는 기본 카메라처럼 숨김
        .opacity(camera.captureActivity.isRecording ? 0 : 1)
    }

    private func segment(for mode: CaptureMode) -> some View {
        let isSelected = camera.captureMode == mode
        return Button {
            camera.captureMode = mode
        } label: {
            Text(mode.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSelected ? Color.cameraYellow : .white)
                .frame(width: segmentSize.width, height: segmentSize.height)
                .background {
                    if isSelected {
                        Capsule().fill(.white.opacity(0.18))
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CaptureModePicker(camera: PreviewCameraModel())
        .padding()
        .background(.black)
}
