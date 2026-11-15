//
//  SplitControls.swift
//  포징
//
//  분할 사진 조작 (docs/02_UI.md 7-1절).
//  - 셔터 오른쪽 분할 버튼: 탭하면 위로 1 · 2 · 3 · 4 목록 (카메라 목록과 같은 방식).
//    분할 중이면 버튼 테두리 안에 찍은 칸을 합친 모양, 꾹 누르면 크게 띄움
//  - 미리보기 오른쪽 위 토글: 아래로 칸별 사진 목록 열고 닫기. 칸을 누르면 그 칸을 다시 찍음(꾹 누르면 그 사진 크게), 지금 칸은 노란 테두리
//  - 모든 칸을 찍으면 셔터가 노란 저장 버튼으로 바뀜. 토글 묶음은 가로로 돌리면 묶음째 돌아 왼쪽으로 눕히면 왼쪽 위, 오른쪽으로 눕히면 오른쪽 아래(보는 사람 기준)
//

import SwiftUI

/// 분할 모양 그림: 사진 비율 사각형 안에 칸 경계선
struct SplitGlyph: View {

    let layout: SplitLayout
    var heightRatio: CGFloat = 4.0 / 3
    var width: CGFloat = 26
    var color: Color = .white

    var body: some View {
        let size = CGSize(width: width, height: width * heightRatio)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(color, lineWidth: 1.5)
            Path { path in
                for index in 0..<layout.count {
                    let rect = layout.cellRect(index, in: size)
                    // 오른쪽 · 아래 경계만 그림 (바깥 테두리는 위 사각형)
                    if rect.maxX < size.width - 0.5 {
                        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                    if rect.maxY < size.height - 0.5 {
                        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                }
            }
            .stroke(color, lineWidth: 1.2)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// 셔터 오른쪽 분할 버튼. 기본(1장)은 POSING 로고만, 분할 중이면 아래에 "2분할" 같은 이름 (카메라 버튼 이름과 같은 글자)
struct SplitButton: View {

    let split: SplitShotState
    /// 사진 비율 (세로 기준 높이 / 폭)
    let heightRatio: CGFloat
    @Binding var isListOpen: Bool
    /// 분할 중 꾹 누르면 합친 모양 크게 보기
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        icon
            .frame(width: CameraLookList.cellSize, height: CameraLookList.cellSize)
            .overlay(alignment: .bottom) {
                // 기본(1장)은 로고만, 분할 중이면 "2분할" 같은 이름
                if split.isActive {
                    Text(Self.name(split.layout))
                        .font(.system(size: AppDefaults.cameraNameFontSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize()
                        .offset(y: AppDefaults.cameraNameGap + AppDefaults.cameraNameFontSize)
                }
            }
            .scaleEffect(isPressed ? 1.08 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            // 이름이 있으면 그림 + 이름 덩어리의 가운데가 셔터 가운데에 오게 올림 (카메라 버튼과 같은 방식)
            .offset(y: -lift)
            .rotatesWithDevice()
            .contentShape(.rect)
            .onTapGesture { isListOpen.toggle() }
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                if split.isActive { onLongPress() }
            } onPressingChanged: { isPressed = $0 && split.isActive }
            .accessibilityElement()
            .accessibilityLabel("분할")
            .accessibilityValue(Self.name(split.layout))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "크게 보기") { if split.isActive { onLongPress() } }
    }

    /// 분할 중이면 분할 모양 테두리 안에 찍은 칸을 합친 모양 (카메라 버튼의 카메라 그림처럼), 아니면 POSING 로고
    @ViewBuilder
    private var icon: some View {
        let width = min(Self.iconWidth, CameraLookList.cellSize / heightRatio)
        if split.isActive {
            SplitComposite(split: split, size: CGSize(width: width, height: width * heightRatio),
                           numberSize: min(10, width * 0.3), rotatesNumber: false)
                .clipShape(.rect(cornerRadius: 3))
                .overlay {
                    SplitGlyph(layout: split.layout, heightRatio: heightRatio, width: width, color: .cameraYellow)
                }
        } else {
            // 기본(1장): 상자 · 이름 없이 POSING 로고만. 누르면 분할 목록
            Image("PosingLogo")
                .resizable()
                .scaledToFit()
                .frame(width: AppDefaults.splitLogoWidth)
        }
    }

    private static var iconWidth: CGFloat { 34 }

    /// 그림 위 끝 ~ 이름 아래 끝의 가운데를 버튼 가운데로 (로고만 있을 때는 그대로)
    private var lift: CGFloat {
        guard split.isActive else { return 0 }
        let width = min(Self.iconWidth, CameraLookList.cellSize / heightRatio)
        let nameBottom = CameraLookList.cellSize / 2 + AppDefaults.cameraNameBottomBelowCell
        return max(0, (nameBottom - width * heightRatio / 2) / 2)
    }

    static func name(_ layout: SplitLayout) -> String {
        layout == .single ? "1장" : "\(layout.count)분할"
    }
}

/// 분할 버튼 위로 쌓이는 세로 목록 (위에서부터 1 · 2 · 3 · 4). 지금 분할은 노란색
struct SplitLayoutList: View {

    let split: SplitShotState
    let onSelect: (SplitLayout) -> Void

    private static let spacing: CGFloat = 10
    private static let padding: CGFloat = 8
    private static let cellHeight: CGFloat = CameraLookList.cellSize

    var height: CGFloat {
        let count = CGFloat(SplitLayout.allCases.count)
        return count * Self.cellHeight + (count - 1) * Self.spacing + Self.padding * 2
    }

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(SplitLayout.allCases) { layout in
                let isSelected = layout == split.layout
                Button {
                    onSelect(layout)
                } label: {
                    SplitGlyph(layout: layout, width: 30, color: isSelected ? .cameraYellow : .white)
                        .frame(width: CameraLookList.cellSize, height: Self.cellHeight)
                        .rotatesWithDevice()
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SplitButton.name(layout))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Self.padding)
        .frame(width: CameraLookList.width, height: height)
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 16))
    }
}


/// 미리보기 오른쪽 위 묶음: 토글 ("2/4"), 토글 아래에 칸별 사진 목록 (토글 가운데 정렬).
/// 가로로 돌리면 묶음 전체를 돌려서 보는 사람 기준 왼쪽 위에 붙고, 목록은 여전히 토글 아래로 열림
struct SplitCellPanel<CameraModel: Camera>: View {

    let camera: CameraModel
    /// 사진 비율 (세로 기준 높이 / 폭)
    let heightRatio: CGFloat
    /// 크게 보기 (칸별 사진 꾹 누르기)
    let onPreview: (SplitPreviewTarget) -> Void

    @Environment(\.iconAngle) private var iconAngle

    private var split: SplitShotState { camera.splitShot }

    private static var spacing: CGFloat { 8 }
    private static var listSpacing: CGFloat { 6 }
    private static var toggleHeight: CGFloat { topBarControlHeight }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isSideways = abs(iconAngle) > 45
            let inner = isSideways ? CGSize(width: size.height, height: size.width) : size
            // 보는 사람 기준 자리: 세로 = 오른쪽 위, 왼쪽으로 눕힘 = 왼쪽 위, 오른쪽으로 눕힘 = 오른쪽 아래
            // (오른쪽으로 눕히면 토글이 아래라 목록이 토글 위로 열림)
            // 돌면서 자리가 흔들리지 않게 사라짐 · 움직임 없이 바로 새 방향으로
            cluster(cellWidth: fittingCellWidth(available: inner.height))
                .padding(AppDefaults.splitClusterInset)
                .frame(width: inner.width, height: inner.height,
                       alignment: !isSideways ? .topTrailing : opensUpward ? .bottomTrailing : .topLeading)
                .rotationEffect(.degrees(iconAngle))
                .frame(width: size.width, height: size.height)
        }
        .transaction(value: iconAngle) { $0.animation = nil }
    }

    /// 오른쪽으로 눕힘: 토글이 아래에 있어 목록을 토글 위로 엶
    private var opensUpward: Bool { iconAngle < -45 }

    /// 토글 + (열면) 칸별 사진 목록. 목록은 토글 가운데에 맞춤, 보통은 토글 아래 · 오른쪽으로 눕히면 토글 위
    private func cluster(cellWidth: CGFloat) -> some View {
        VStack(alignment: .center, spacing: Self.spacing) {
            if !opensUpward { toggleButton }
            if split.isPanelOpen {
                VStack(alignment: .center, spacing: Self.listSpacing) {
                    ForEach(0..<split.layout.count, id: \.self) { index in
                        shotCell(index, width: cellWidth)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: opensUpward ? .bottom : .top)))
            }
            if opensUpward { toggleButton }
        }
        .animation(.easeOut(duration: 0.2), value: split.isPanelOpen)
    }

    /// 포즈 · MY 버튼과 같은 크기 · 글자의 유리 캡슐 (상단 캡슐은 회색 판, 토글만 유리)
    private var toggleButton: some View {
        HStack(spacing: 4) {
            Text("\(filledCount)/\(split.layout.count)")
                .monospacedDigit()
            // 화살표는 목록을 접는 쪽을 가리킴 (아래로 열리면 열린 동안 위, 위로 열리면 열린 동안 아래)
            Image(systemName: split.isPanelOpen != opensUpward ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .bold))
        }
        .topBarCapsule(horizontalPadding: 12, isGlass: true)
        .contentShape(.capsule)
        .onTapGesture { split.isPanelOpen.toggle() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(split.isPanelOpen ? "칸 목록 닫기" : "칸 목록 열기")
        .accessibilityAddTraits(.isButton)
    }

    /// 칸 하나: 칸 비율 그대로, 배경 없이 사진 + 테두리. 누르면 그 칸을 다시 찍음
    /// 칸 하나의 높이 / 폭
    private func shotCellRatio(_ index: Int) -> CGFloat {
        let cell = split.layout.cellRect(index, in: CGSize(width: 1, height: heightRatio))
        return min(cell.height / cell.width, 1.6)
    }

    /// 묶음이 미리보기 안에 다 들어가는 칸 폭 (기본 52pt, 가로로 돌려 높이가 모자라면 줄임)
    private func fittingCellWidth(available: CGFloat) -> CGFloat {
        let preferred = AppDefaults.splitPanelCellWidth
        let count = split.layout.count
        var perWidth: CGFloat = 0
        var fixed = AppDefaults.splitClusterInset * 2 + Self.toggleHeight
        if split.isPanelOpen {
            perWidth = (0..<count).reduce(0) { $0 + shotCellRatio($1) }
            fixed += Self.spacing + Self.listSpacing * CGFloat(count - 1)
        }
        guard perWidth > 0 else { return preferred }
        return max(24, min(preferred, (available - fixed) / perWidth))
    }

    private func shotCell(_ index: Int, width cellWidth: CGFloat) -> some View {
        let height = cellWidth * shotCellRatio(index)
        let isCurrent = index == split.currentIndex
        return SplitCellImage(shot: split.shots[index], number: index + 1,
                              isPending: split.pendingIndices.contains(index),
                              numberSize: min(15, height * 0.6), rotatesNumber: false)
            .frame(width: cellWidth, height: height)
            .clipShape(.rect(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isCurrent ? Color.cameraYellow : .white.opacity(0.6),
                                  lineWidth: isCurrent ? AppDefaults.splitCurrentBorderWidth : 1)
            }
            .contentShape(.rect)
            .onTapGesture { split.select(index) }
            // 찍은 칸을 꾹 누르면 그 사진만 크게
            .onLongPressGesture(minimumDuration: AppDefaults.longPressDuration) {
                if split.shots[index] != nil { onPreview(.cell(index)) }
            }
            .accessibilityElement()
            .accessibilityLabel("\(index + 1)번 칸")
            .accessibilityValue(split.shots[index] == nil ? "찍지 않음" : "찍음")
            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var filledCount: Int { split.shots.count { $0 != nil } }
}

/// 크게 보기 대상
enum SplitPreviewTarget: Equatable {
    /// 찍은 칸을 합친 모양
    case combined
    /// 칸 하나의 사진
    case cell(Int)
}

/// 찍은 칸을 합친 모양 (줄 없이 붙임, 안 찍은 칸은 진한 회색에 번호)
struct SplitComposite: View {

    let split: SplitShotState
    let size: CGSize
    let numberSize: CGFloat
    var rotatesNumber = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<split.layout.count, id: \.self) { index in
                let rect = split.layout.cellRect(index, in: size)
                SplitCellImage(shot: split.shots[index], number: index + 1, numberSize: numberSize,
                               rotatesNumber: rotatesNumber)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// 크게 보기: 합친 모양(분할 버튼 꾹 누르기) 또는 칸 하나(칸별 사진 꾹 누르기). 아무 곳이나 누르면 닫힘
struct SplitLargePreview: View {

    let split: SplitShotState
    let target: SplitPreviewTarget
    /// 사진 비율 (세로 기준 높이 / 폭)
    let heightRatio: CGFloat
    let screenSize: CGSize
    let onClose: () -> Void

    var body: some View {
        let ratio = contentRatio
        let maxWidth = screenSize.width - AppDefaults.splitLargePreviewInset * 2
        let maxHeight = screenSize.height * 0.75
        let width = min(maxWidth, maxHeight / ratio)
        let size = CGSize(width: width, height: width * ratio)
        ZStack {
            Color.black.opacity(0.85)
            switch target {
            case .combined:
                SplitComposite(split: split, size: size, numberSize: 40)
                    .clipped()
            case .cell(let index):
                SplitCellImage(shot: split.shots.indices.contains(index) ? split.shots[index] : nil,
                               number: index + 1, numberSize: 40)
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .contentShape(.rect)
        .onTapGesture(perform: onClose)
        .accessibilityElement()
        .accessibilityLabel("크게 보기")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "닫기", onClose)
    }

    /// 높이 / 폭
    private var contentRatio: CGFloat {
        switch target {
        case .combined:
            return heightRatio
        case .cell(let index):
            let cell = split.layout.cellRect(index, in: CGSize(width: 1, height: heightRatio))
            return cell.width > 0 ? cell.height / cell.width : heightRatio
        }
    }
}
