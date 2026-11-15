/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A Control Center extension for AVCam.
*/

import SwiftUI
import WidgetKit
import AppIntents

struct AVCamControlCenterExtension: ControlWidget {
    
    static var kind = "com.example.apple-samplecode.AVCam.AVCamControlCenterExtension.ControlButton"
    static var displayName: LocalizedStringResource = "포징 열기"
    static var description: LocalizedStringResource = "포징 앱을 엽니다."
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: AVCamControlCenterExtension.kind) {
            ControlWidgetButton(action: AVCamCaptureIntent()) {
                Label("포징 열기", systemImage: "curlybraces")
            }
        }
        .displayName(AVCamControlCenterExtension.displayName)
        .description(AVCamControlCenterExtension.description)
    }
}
