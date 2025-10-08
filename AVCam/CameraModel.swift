/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that provides the interface to the features of the camera.
*/

import SwiftUI
import Combine
import os.log
import AVFoundation


/// An object that provides the interface to the features of the camera.
///
/// This object provides the default implementation of the `Camera` protocol, which defines the interface
/// to configure the camera hardware and capture media. `CameraModel` doesn't perform capture itself, but is an
/// `@Observable` type that mediates interactions between the app's SwiftUI views and `CaptureService`.
///
/// For SwiftUI previews and Simulator, the app uses `PreviewCameraModel` instead.
///
@MainActor
@Observable
final class CameraModel: Camera {

    private let logger = Logger(subsystem: "com.apple.AVCam", category: "CameraModel")

    /// The current status of the camera, such as unauthorized, running, or failed.
    private(set) var status = CameraStatus.unknown

    /// The current state of photo or movie capture.
    private(set) var captureActivity = CaptureActivity.idle

    /// A Boolean value that indicates whether the app is currently switching video devices.
    private(set) var isSwitchingVideoDevices = false

    /// A Boolean value that indicates whether the camera prefers showing a minimized set of UI controls.
    private(set) var prefersMinimizedUI = false

    /// A Boolean value that indicates whether the app is currently switching capture modes.
    private(set) var isSwitchingModes = false

    /// A Boolean value that indicates whether to show visual feedback when capture begins.
    private(set) var shouldFlashScreen = false

    /// A thumbnail for the last captured photo or video.
    private(set) var thumbnail: CGImage?

    /// An error that indicates the details of an error during photo or movie capture.
    private(set) var error: Error?

    /// An object that provides the connection between the capture session and the video preview layer.
    var previewSource: PreviewSource { captureService.previewSource }

    /// A configuration describing simultaneous front/back preview feeds when available.
    private(set) var multiCamPreviewConfiguration: MultiCamPreviewConfiguration?

    /// A Boolean value that indicates whether multi-camera mode is supported on this device.
    var isMultiCamSupported: Bool {
        if #available(iOS 13.0, *) {
            return AVCaptureMultiCamSession.isMultiCamSupported
        } else {
            return false
        }
    }

    /// A Boolean value indicating if running on simulator
    var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// A Boolean value that indicates whether multi-camera mode is currently active.
    var isMultiCamActive: Bool {
        multiCamPreviewConfiguration != nil
    }

    /// The current multi-camera layout when multi-cam is active.
    var multiCamLayout: MultiCameraConfiguration.MultiCamLayout = .pictureInPicture

    /// A Boolean that indicates whether the camera supports HDR video recording.
    private(set) var isHDRVideoSupported = false

    /// A Boolean that indicates whether cinematic video is supported.
    private(set) var isCinematicVideoSupported = false

    /// A Boolean that indicates whether spatial video is supported.
    private(set) var isSpatialVideoSupported = false

    /// Current performance metrics from the capture service.
    private(set) var performanceMetrics: PerformanceMetrics = .unknown

    /// A Boolean value that indicates whether Live Photo capture is enabled.
    var isLivePhotoEnabled = false {
        didSet {
            cameraState.isLivePhotoEnabled = isLivePhotoEnabled
        }
    }

    /// A value that indicates the quality prioritization for photo capture.
    var qualityPrioritization = QualityPrioritization.quality {
        didSet {
            cameraState.qualityPrioritization = qualityPrioritization
        }
    }

    /// A Boolean value that indicates whether HDR video is enabled.
    var isHDRVideoEnabled = false {
        didSet {
            cameraState.isVideoHDREnabled = isHDRVideoEnabled
        }
    }

    /// A Boolean value that indicates whether cinematic video is enabled.
    var isCinematicVideoEnabled = false {
        didSet {
            cameraState.isCinematicVideoEnabled = isCinematicVideoEnabled
        }
    }

    /// A Boolean value that indicates whether spatial video is enabled.
    var isSpatialVideoEnabled = false {
        didSet {
            cameraState.isSpatialVideoEnabled = isSpatialVideoEnabled
        }
    }

    /// An object that saves captured media to a person's Photos library.
    private let mediaLibrary = MediaLibrary()

    /// An object that manages the app's capture functionality.
    private let captureService = CaptureService()

    /// Persistent state shared between the app and capture extension.
    private var cameraState = CameraState()

    init() {
        //
    }

    // MARK: - Starting the camera
    /// Start the camera and begin the stream of data.
    func start() async {
        // Verify that the person authorizes the app to use device cameras and microphones.
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        do {
            // Synchronize the state of the model with the persistent state.
            await syncState()
            // Start the capture service to start the flow of data.
            try await captureService.start(with: cameraState)
            observeState()
            status = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }

    /// Synchronizes the persistent camera state.
    ///
    /// `CameraState` represents the persistent state, such as the capture mode, that the app and extension share.
    func syncState() async {
        cameraState = await CameraState.current
        captureMode = cameraState.captureMode
        qualityPrioritization = cameraState.qualityPrioritization
        isLivePhotoEnabled = cameraState.isLivePhotoEnabled
        isHDRVideoEnabled = cameraState.isVideoHDREnabled

        // Sync new feature states
        isCinematicVideoEnabled = cameraState.isCinematicVideoEnabled
        isSpatialVideoEnabled = cameraState.isSpatialVideoEnabled
        multiCamLayout = cameraState.multiCamLayout
    }

    // MARK: - Changing modes and devices

    /// A value that indicates the mode of capture for the camera.
    var captureMode = CaptureMode.photo {
        didSet {
            guard status == .running else { return }
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                // Update the configuration of the capture service for the new mode.
                try? await captureService.setCaptureMode(captureMode)
                // Update the persistent state value.
                cameraState.captureMode = captureMode
            }
        }
    }

    /// Selects the next available video device for capture.
    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false }
        await captureService.selectNextVideoDevice()
    }

    /// Explicitly enable dual (multi-camera) mode if supported.
    @MainActor
    func enableMultiCam() async -> Bool {
        logger.info("User requested dual camera mode")
        let success = await captureService.enableMultiCam()
        if success {
            // Default to grid layout for multi-cam as per user preference
            multiCamLayout = .grid
            logger.info("✅ Dual camera mode enabled successfully with grid layout")
        } else {
            logger.error("❌ Failed to enable dual camera mode - check device compatibility and console logs")
            // Set error for UI feedback
            error = NSError(
                domain: "com.apple.AVCam",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Dual camera mode failed to activate",
                    NSLocalizedRecoverySuggestionErrorKey: "This may be due to device limitations, thermal throttling, or incompatible camera formats. Check console logs for details."
                ]
            )
        }
        return success
    }

    /// Explicitly disable dual (multi-camera) mode and return to single camera.
    @MainActor
    func disableMultiCam() async {
        await captureService.disableMultiCam()
    }

    /// Sets the rear camera zoom to a specific preset value.
    @MainActor
    func setRearZoomPreset(_ preset: RearZoomPreset) {
        Task {
            switch preset {
            case .ultraWide_0_5x:
                await captureService.setRearZoom(factor: 0.5)
            case .wide_1x:
                await captureService.setRearZoom(factor: 1.0)
            case .tele_2x:
                await captureService.setRearZoom(factor: 2.0)
            }
        }
    }

    // MARK: - Photo capture

    /// Captures a photo and writes it to the user's Photos library.
    func capturePhoto() async {
        do {
            let photoFeatures = PhotoFeatures(isLivePhotoEnabled: isLivePhotoEnabled, qualityPrioritization: qualityPrioritization)
            let photo = try await captureService.capturePhoto(with: photoFeatures)
            try await mediaLibrary.save(photo: photo)
        } catch {
            self.error = error
        }
    }

    // Properties isLivePhotoEnabled and qualityPrioritization are declared above

    /// Performs a focus and expose operation at the specified screen point.
    func focusAndExpose(at point: CGPoint) async {
        await captureService.focusAndExpose(at: point)
    }

    /// Sets the `showCaptureFeedback` state to indicate that capture is underway.
    private func flashScreen() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
    }

    // MARK: - Video capture
    // Property isHDRVideoEnabled is declared above

    /// Toggles the state of recording.
    func toggleRecording() async {
        switch await captureService.captureActivity {
        case .movieCapture:
            do {
                // If currently recording, stop the recording and write the movie to the library.
                let movie = try await captureService.stopRecording()
                try await mediaLibrary.save(movie: movie)
            } catch {
                self.error = error
            }
        default:
            // In any other case, start recording.
            await captureService.startRecording()
        }
    }

    // MARK: - Internal state observations

    // Set up camera's state observations.
    private func observeState() {
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
                cameraState.isVideoHDRSupported = capabilities.isHDRSupported
            }
        }

        Task {
            // Await performance metrics updates
            for await metrics in await captureService.$performanceMetrics.values {
                performanceMetrics = metrics
            }
        }

        Task {
            // Await cinematic video state changes
            for await isCinematicEnabled in await captureService.$isCinematicVideoEnabled.values {
                isCinematicVideoEnabled = isCinematicEnabled
                cameraState.isCinematicVideoEnabled = isCinematicEnabled
            }
        }

        Task {
            // Await spatial video state changes
            for await isSpatialEnabled in await captureService.$isSpatialVideoEnabled.values {
                isSpatialVideoEnabled = isSpatialEnabled
                cameraState.isSpatialVideoEnabled = isSpatialEnabled
            }
        }

        Task {
            for await configuration in await captureService.$multiCamPreviewConfiguration.values {
                self.multiCamPreviewConfiguration = configuration
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
