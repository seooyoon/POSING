//
//  CameraModel+Split.swift
//  포징
//
//  분할 사진 촬영 · 저장 (docs/01_SPEC.md 7-2절).
//  셔터로 찍은 사진은 사진 앱 대신 지금 칸에 넣고, 저장 버튼을 누르면 합친 사진(+ 칸 크기로 자른 칸별 원본)을 저장한다.
//

import Foundation

extension CameraModel {

    /// 찍은 사진을 칸에 넣음 (작은 그림은 메인 스레드 밖에서 만듦)
    func storeSplitShot(_ photo: Photo, at index: Int, session: Int) async {
        let data = photo.data
        let shot = await Task.detached(priority: .userInitiated) { SplitShot.make(from: data) }.value
        splitShot.finishCapture(shot, at: index, session: session)
    }

    /// 저장 버튼: 합친 사진(+ 설정에 따라 칸별 원본)을 사진 앱에 저장하고 처음부터
    func saveSplitShot() async {
        guard splitShot.isComplete, !splitShot.isSaving else { return }
        splitShot.isSaving = true
        defer { splitShot.isSaving = false }
        let shots = splitShot.shots.compactMap { $0?.data }
        let layout = splitShot.layout
        let heightRatio = photoAspect.portraitHeightRatio
        let savesOriginals = UserDefaults.standard.object(forKey: SettingsKeys.savesSplitOriginals) as? Bool
            ?? AppDefaults.savesSplitOriginals
        do {
            let (combined, originals) = await Task.detached(priority: .userInitiated) {
                let combined = SplitComposer.compose(shots, layout: layout, heightRatio: heightRatio)
                // 칸별 원본은 그 칸 크기(비율)대로 잘라서
                let originals = savesOriginals
                    ? shots.enumerated().map { index, data in
                        SplitComposer.cropToCell(data, index: index, layout: layout, heightRatio: heightRatio) ?? data
                    }
                    : []
                return (combined, originals)
            }.value
            guard let combined else { throw SplitShotError.composeFailed }
            // 원본 먼저, 합친 사진을 마지막에 (썸네일 · 사진 앱 맨 끝이 합친 사진)
            for data in originals {
                try await mediaLibrary.save(photo: Photo(data: data, isProxy: false, livePhotoMovieURL: nil))
            }
            try await mediaLibrary.save(photo: Photo(data: combined, isProxy: false, livePhotoMovieURL: nil))
            splitShot.reset()
        } catch {
            self.error = error
            logger.notice("[Split] save failed: \(String(describing: error), privacy: .public)")
        }
    }
}

enum SplitShotError: Error {
    case composeFailed
}
