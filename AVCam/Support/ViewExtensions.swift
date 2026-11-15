/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Extensions and supporting SwiftUI types.
*/

import SwiftUI
import UIKit

@MainActor
protocol PlatformView: View {
    var verticalSizeClass: UserInterfaceSizeClass? { get }
    var horizontalSizeClass: UserInterfaceSizeClass? { get }
    var isRegularSize: Bool { get }
    var isCompactSize: Bool { get }
}

extension PlatformView {
    var isRegularSize: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    var isCompactSize: Bool { horizontalSizeClass == .compact || verticalSizeClass == .compact }
}

extension View {
    /// Hides this view until the capture session is running.
    ///
    /// The app applies this to its controls so that it doesn't show UI until it's
    /// functional, and so the preview is the first thing to appear at launch.
    func hidden(until isRunning: Bool) -> some View {
        opacity(isRunning ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: isRunning)
    }
}

extension Image {
    init(_ image: CGImage) {
        self.init(uiImage: UIImage(cgImage: image))
    }
}
