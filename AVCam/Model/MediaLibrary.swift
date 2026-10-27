/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that writes photos and movies to the user's Photos library.
*/

import Foundation
import Photos
import UIKit
import ImageIO
import AVFoundation

/// An object that writes photos and movies to the user's Photos library.
actor MediaLibrary {
    
    // Errors that media library can throw.
    enum Error: Swift.Error {
        case unauthorized
        case saveFailed
    }
    
    /// An asynchronous stream of thumbnail images the app generates after capturing media.
    let thumbnails: AsyncStream<CGImage?>
    private let continuation: AsyncStream<CGImage?>.Continuation?
    
    /// Creates a new media library object.
    init() {
        let (thumbnails, continuation) = AsyncStream.makeStream(of: CGImage?.self)
        self.thumbnails = thumbnails
        self.continuation = continuation
    }
    
    // MARK: - Authorization
    
    private var isAuthorized: Bool {
        get async {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            /// Determine whether the user has previously authorized `PHPhotoLibrary` access.
            var isAuthorized = status == .authorized
            // If the system hasn't determined the user's authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                // Request authorization to add media to the library.
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                isAuthorized = status == .authorized
            }
            return isAuthorized
        }
    }

    // MARK: - Saving media
    
    /// Saves a photo to the Photos library.
    func save(photo: Photo) async throws {
        let location = try await currentLocation
        let thumbnail = makeThumbnail(from: photo.data)
        try await performChange(thumbnail: thumbnail) {
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // Save primary photo.
            let options = PHAssetResourceCreationOptions()
            // Specify the appropriate resource type for the photo.
            creationRequest.addResource(with: photo.isProxy ? .photoProxy : .photo, data: photo.data, options: options)
            creationRequest.location = location
            
            // Save Live Photo data.
            if let url = photo.livePhotoMovieURL {
                let livePhotoOptions = PHAssetResourceCreationOptions()
                livePhotoOptions.shouldMoveFile = true
                creationRequest.addResource(with: .pairedVideo, fileURL: url, options: livePhotoOptions)
            }
            
        }
    }
    
    /// Saves a movie to the Photos library.
    func save(movie: Movie) async throws {
        let location = try await currentLocation
        // 저장하면서 파일이 옮겨지므로 썸네일을 먼저 만든다
        let thumbnail = await makeThumbnail(fromMovieAt: movie.url)
        try await performChange(thumbnail: thumbnail) {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: movie.url, options: options)
            creationRequest.location = location
        }
    }
    
    // A template method for writing a change to the user's photo library.
    private func performChange(thumbnail: CGImage?, _ change: @Sendable @escaping () -> Void) async throws {
        guard await isAuthorized else {
            throw Error.unauthorized
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                // Execute the change closure.
                change()
            }
            // 저장에 성공하면 미리 만든 썸네일을 화면에 보냄
            continuation?.yield(thumbnail)
        } catch {
            throw Error.saveFailed
        }
    }
    
    // MARK: - Thumbnail handling
    
    // 사진 앱 읽기 권한(.addOnly만 사용)이 없어서 저장한 항목을 다시 읽을 수 없다.
    // 그래서 찍은 데이터로 직접 썸네일을 만든다 (05_TECH_NOTES 7절).
    private let thumbnailMaxPixelSize = 256
    
    private func makeThumbnail(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 사진 방향(EXIF)을 반영
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
    
    private func makeThumbnail(fromMovieAt url: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        // 영상 방향을 반영
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailMaxPixelSize, height: thumbnailMaxPixelSize)
        return try? await generator.image(at: .zero).image
    }
    
    // MARK: - Location management
    
    private let locationManager = CLLocationManager()
    
    private var currentLocation: CLLocation? {
        get async throws {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // Return the location for the first update.
            return try await CLLocationUpdate.liveUpdates().first(where: { _ in true })?.location
        }
    }
}

