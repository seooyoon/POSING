//
//  CameraModel+Observation.swift
//  포징
//
//  CameraModel이 캡처 서비스 상태를 받아 화면 값으로 옮기는 부분 (파일 400줄 제한으로 분리).
//

import SwiftUI

extension CameraModel {

    // MARK: - Internal state observations
    
    // Set up camera's state observations.
    func observeState() {
        // 장면 밝기 · 꽃 버튼용 피사체 거리를 0.5초마다 확인 (노출 · 초점 값만 읽음)
        Task { [weak self] in
            while let service = self?.captureService {
                let ev = await service.sceneEV
                self?.sceneBrightness.update(ev: ev)
                await service.refreshSubjectDistance()
                try? await Task.sleep(for: .seconds(0.5))
            }
        }

        Task {
            // Await new thumbnails that the media library generates when saving a file.
            for await thumbnail in mediaLibrary.thumbnails.compactMap({ $0 }) {
                self.thumbnail = thumbnail
            }
        }
        
        Task {
            // Await new capture activity values from the capture service.
            for await activity in await captureService.$captureActivity.values {
                if activity.willCapture {
                    // Flash the screen to indicate capture is starting.
                    flashScreen()
                } else {
                    // Forward the activity to the UI.
                    captureActivity = activity
                }
            }
        }
        
        Task {
            // Await updates to the capabilities that the capture service advertises.
            for await capabilities in await captureService.$captureCapabilities.values {
                isHDRVideoSupported = capabilities.isHDRSupported
                applyPhotoCapabilities(capabilities)
                if !capabilities.videoModes.isEmpty { availableVideoModes = capabilities.videoModes }
                cameraState.isVideoHDRSupported = capabilities.isHDRSupported
            }
        }
        
        Task {
            // 배율 · 접사 상태 (카메라 컨트롤 버튼으로 바꿔도 따라옴)
            for await zoom in await captureService.$zoomState.values {
                self.zoom = zoom
            }
        }

        Task {
            // 렌즈 얼룩 감지 결과
            for await isLensSmudged in await captureService.$isLensSmudged.values {
                withAnimation {
                    self.isLensSmudged = isLensSmudged
                }
            }
        }

        Task {
            // Await updates to a person's interaction with the Camera Control HUD.
            for await isShowingFullscreenControls in await captureService.$isShowingFullscreenControls.values {
                withAnimation {
                    // Prefer showing a minimized UI when capture controls enter a fullscreen appearance.
                    prefersMinimizedUI = isShowingFullscreenControls
                }
            }
        }
    }
}
