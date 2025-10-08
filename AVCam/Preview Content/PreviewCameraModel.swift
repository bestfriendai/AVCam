/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A Camera implementation to use when working with SwiftUI previews.
*/

import Foundation
import SwiftUI

@Observable
class PreviewCameraModel: Camera {

    var isLivePhotoEnabled = true
    var prefersMinimizedUI = false
    var qualityPrioritization = QualityPrioritization.quality
    var shouldFlashScreen = false
    var isHDRVideoSupported = false
    var isHDRVideoEnabled = false

    struct PreviewSourceStub: PreviewSource {
        // Stubbed out for test purposes.
        func connect(to target: PreviewTarget) {}
    }

    let previewSource: PreviewSource = PreviewSourceStub()
    let multiCamPreviewConfiguration: MultiCamPreviewConfiguration? = nil
    let isMultiCamSupported = false
    let isMultiCamActive = false
    var multiCamLayout: MultiCameraConfiguration.MultiCamLayout = .pictureInPicture
    let isRunningOnSimulator = true

    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    var captureMode = CaptureMode.photo {
        didSet {
            isSwitchingModes = true
            Task {
                // Create a short delay to mimic the time it takes to reconfigure the session.
                try? await Task.sleep(until: .now + .seconds(0.3), clock: .continuous)
                self.isSwitchingModes = false
            }
        }
    }
    private(set) var isSwitchingModes = false
    private(set) var isVideoDeviceSwitchable = true
    private(set) var isSwitchingVideoDevices = false
    private(set) var thumbnail: CGImage?

    var error: Error?

    /// The state machine managing camera session state (stub for previews)
    let sessionState = CameraSessionState()

    /// Visual feedback system for user-facing messages (stub for previews)
    let feedback = CameraFeedback()

    init(captureMode: CaptureMode = .photo, status: CameraStatus = .unknown) {
        self.captureMode = captureMode
        self.status = status
    }

    func start() async {
        if status == .unknown {
            status = .running
        }
    }

    func switchVideoDevices() {
        logger.debug("Device switching isn't implemented in PreviewCamera.")
    }

    func capturePhoto() {
        logger.debug("Photo capture isn't implemented in PreviewCamera.")
    }

    func toggleRecording() {
        logger.debug("Moving capture isn't implemented in PreviewCamera.")
    }

    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }

    var recordingTime: TimeInterval { .zero }

    private func capabilities(for mode: CaptureMode) -> CaptureCapabilities {
        switch mode {
        case .photo:
            return CaptureCapabilities(isLivePhotoCaptureSupported: true)
        case .video:
            return CaptureCapabilities(isLivePhotoCaptureSupported: false,
                                       isHDRSupported: true)
        }
    }

    func enableMultiCam() async -> Bool { false }
    func disableMultiCam() async { }

    func setRearZoomPreset(_ preset: RearZoomPreset) {
        logger.debug("Zoom preset isn't implemented in PreviewCamera.")
    }

    func syncState() async {
        logger.debug("Syncing state isn't implemented in PreviewCamera.")
    }
}
