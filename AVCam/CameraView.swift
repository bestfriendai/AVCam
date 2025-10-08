/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

@MainActor
struct CameraView<CameraModel: Camera>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var camera: CameraModel

    // The direction a person swipes on the camera preview or mode selector.
    @State var swipeDirection = SwipeDirection.left

    var body: some View {
        ZStack {
            // A container view that manages the placement of the preview.
            PreviewContainer(camera: camera) {
                // A view that provides a preview of the captured content.
                Group {
                    if let configuration = camera.multiCamPreviewConfiguration {
                        MultiCamPreview(configuration: configuration, layout: camera.multiCamLayout)
                    } else {
                        CameraPreview(source: camera.previewSource)
                    }
                }
                    // Handle capture events from device hardware buttons.
                    .onCameraCaptureEvent(defaultSoundDisabled: true) { event in
                        if event.phase == .ended {
                            let sound: AVCaptureEventSound
                            switch camera.captureMode {
                            case .photo:
                                sound = .cameraShutter
                                // Capture a photo when pressing a hardware button.
                                await camera.capturePhoto()
                            case .video:
                                sound = camera.captureActivity.isRecording ?
                                    .endVideoRecording : .beginVideoRecording
                                // Toggle video recording when pressing a hardware button.
                                await camera.toggleRecording()
                            }
                            // Play a sound when capturing by clicking an AirPods stem.
                            if event.shouldPlaySound {
                                event.play(sound)
                            }
                        }
                    }
                    // Focus and expose at the tapped point.
                    .onTapGesture { location in
                        Task { await camera.focusAndExpose(at: location) }
                    }
                    // Switch between capture modes by swiping left and right.
                    .simultaneousGesture(swipeGesture)
                    /// The value of `shouldFlashScreen` changes briefly to `true` when capture
                    /// starts, and then immediately changes to `false`. Use this change to
                    /// flash the screen to provide visual feedback when capturing photos.
                    .opacity(camera.shouldFlashScreen ? 0 : 1)
            }
            // The main camera user interface.
            CameraUI(camera: camera, swipeDirection: $swipeDirection)

            // Multi-camera status indicator
            if camera.isMultiCamActive {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill.badge.checkmark")
                                .font(.caption)
                            Text(layoutDisplayName(camera.multiCamLayout))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.8))
                        )
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
            }
        }
    }

    private func layoutDisplayName(_ layout: MultiCameraConfiguration.MultiCamLayout) -> String {
        switch layout {
        case .pictureInPicture:
            return "PiP"
        case .sideBySide:
            return "Side by Side"
        case .grid:
            return "Grid"
        case .custom:
            return "Custom"
        }
    }

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture swipe direction.
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel())
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
