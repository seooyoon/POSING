//
//  CameraLayout.swift
//  포징
//
//  기본 카메라 화면(iPhone 16 Pro, docs/reference/photo_main.png)을 기준으로 한 배치 값.
//  모든 위치는 화면 맨 위(안전 영역 포함)를 0으로 하는 좌표다.
//

import SwiftUI

struct CameraLayout {

    /// 상단 바 높이. 사진 모드 미리보기는 이 아래에서 시작
    static let topBarHeight: CGFloat = 66
    /// 사진 모드 미리보기 아래 끝 ~ 셔터 가운데
    static let shutterOffset: CGFloat = 55
    /// 셔터 가운데 ~ 하단 줄 가운데
    static let bottomRowOffset: CGFloat = 96
    /// 화면 좌우 여백
    static let sideInset: CGFloat = 16

    /// 안전 영역을 포함한 전체 화면 크기
    let size: CGSize
    /// 상단 안전 영역 (다이내믹 아일랜드)
    let safeTop: CGFloat
    let captureMode: CaptureMode
    let photoAspect: PhotoAspect

    init(proxy: GeometryProxy, captureMode: CaptureMode, photoAspect: PhotoAspect = .fourThree) {
        let insets = proxy.safeAreaInsets
        size = CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                      height: proxy.size.height + insets.top + insets.bottom)
        safeTop = insets.top
        self.captureMode = captureMode
        self.photoAspect = photoAspect
    }

    var centerX: CGFloat { size.width / 2 }

    var topBarCenterY: CGFloat { safeTop + Self.topBarHeight / 2 }

    /// 4:3 사진 미리보기 자리: 상단 바 아래. 셔터 · 하단 줄의 기준 (비율을 바꿔도 셔터는 그대로)
    var standardPhotoRect: CGRect {
        CGRect(x: 0, y: safeTop + Self.topBarHeight,
               width: size.width, height: size.width * photoAspectRatio.height / photoAspectRatio.width)
    }

    /// 사진 모드: 4:3은 상단 바 아래, 16:9는 비디오처럼 안전 영역 바로 아래, 1:1은 4:3 자리 가운데
    var photoPreviewRect: CGRect {
        let height = size.width * photoAspect.portraitHeightRatio
        switch photoAspect {
        case .fourThree:
            return standardPhotoRect
        case .sixteenNine:
            return CGRect(x: 0, y: safeTop, width: size.width, height: height)
        case .square:
            return CGRect(x: 0, y: standardPhotoRect.midY - height / 2, width: size.width, height: height)
        }
    }

    /// 비디오 모드: 안전 영역 바로 아래부터 16:9, 상단 바가 미리보기 위에 겹침
    var videoPreviewRect: CGRect {
        CGRect(x: 0, y: safeTop,
               width: size.width, height: size.width * movieAspectRatio.height / movieAspectRatio.width)
    }

    var previewRect: CGRect {
        captureMode == .photo ? photoPreviewRect : videoPreviewRect
    }

    /// 셔터와 하단 줄은 모드가 바뀌어도 같은 자리 (기본 카메라와 동일)
    var shutterCenterY: CGFloat { standardPhotoRect.maxY + Self.shutterOffset }

    var bottomRowCenterY: CGFloat { shutterCenterY + Self.bottomRowOffset }

    /// 배율 버튼 줄: 미리보기 아래쪽 안. 비디오(미리보기가 셔터 뒤까지 내려감)도 셔터 위에 오게
    var zoomRowCenterY: CGFloat { min(previewRect.maxY, shutterCenterY - 50) - 30 }
}
