/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that presents controls to enable capture features.
*/

import SwiftUI

/// A view that presents controls to enable capture features.
struct FeaturesToolbar<CameraModel: Camera>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var camera: CameraModel

    var body: some View {
        HStack(spacing: 30) {
            Spacer()
            switch camera.captureMode {
            case .photo:
                livePhotoButton
                prioritizePicker
            case .video:
                multiCamButton
                if camera.isHDRVideoSupported {
                    hdrButton
                }
            }
        }
        .buttonStyle(DefaultButtonStyle(size: isRegularSize ? .large : .small))
        .padding([.leading, .trailing])
        // Hide the toolbar items when a person interacts with capture controls.
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
    }

    //  A button to toggle the enabled state of Live Photo capture.
    var livePhotoButton: some View {
        Button {
            camera.isLivePhotoEnabled.toggle()
        } label: {
            Image(systemName: camera.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
        }
    }

    @ViewBuilder
    var prioritizePicker: some View {
        Menu {
            Picker("Quality Prioritization", selection: $camera.qualityPrioritization) {
                ForEach(QualityPrioritization.allCases) {
                    Text($0.description)
                        .font(.body.weight(.bold))
                }
            }

        } label: {
            switch camera.qualityPrioritization {
            case .speed:
                Image(systemName: "dial.low")
            case .balanced:
                Image(systemName: "dial.medium")
            case .quality:
                Image(systemName: "dial.high")
            }
        }
    }

    @ViewBuilder
    var hdrButton: some View {
        if isCompactSize {
            hdrToggleButton
        } else {
            hdrToggleButton
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }

    var hdrToggleButton: some View {
        Button {
            camera.isHDRVideoEnabled.toggle()
        } label: {
            Text("HDR \(camera.isHDRVideoEnabled ? "On" : "Off")")
                .font(.body.weight(.semibold))
        }
        .disabled(camera.captureActivity.isRecording)
    }

    @ViewBuilder
    var compactSpacer: some View {
        if !isRegularSize {
            Spacer()
        }
    }

    // Multi-camera mode button with layout picker
    var multiCamButton: some View {
        Menu {
            // Multi-camera status section
            Section {
                if camera.isMultiCamActive {
                    Label("Multi-Camera Active", systemImage: "video.fill.badge.checkmark")
                    Text("Simultaneous dual-camera capture enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if camera.isRunningOnSimulator {
                    Label("Simulator Limitation", systemImage: "exclamationmark.triangle")
                    Text("Multi-camera requires a physical device. Deploy to iPhone 11 Pro or newer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !camera.isMultiCamSupported {
                    Label("Not Supported", systemImage: "xmark.circle")
                    Text("This device does not support multi-camera capture. Requires iPhone 11 Pro or newer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Multi-Camera Ready", systemImage: "video.badge.plus")
                    Text("Dual-camera capture will activate in video mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Actions
            if camera.isMultiCamActive {
                Section("Actions") {
                    Button {
                        Task { await camera.switchVideoDevices() }
                    } label: {
                        Label("Switch Screens", systemImage: "arrow.left.arrow.right")
                    }
                    Button {
                        Task { await camera.disableMultiCam() }
                    } label: {
                        Label("Disable Dual Mode", systemImage: "xmark.circle")
                    }
                }
            } else if !camera.isRunningOnSimulator && camera.isMultiCamSupported {
                Section("Actions") {
                    Button {
                        Task {
                            let success = await camera.enableMultiCam()
                            if !success {
                                // Error is now set in CameraModel for user feedback
                                print("⚠️ Dual mode activation failed - check debug overlay for details")
                            }
                        }
                    } label: {
                        Label("Enable Dual Mode", systemImage: "video.badge.plus")
                    }

                    // Show retry option if there was an error
                    if camera.error != nil {
                        Button {
                            Task {
                                // Clear previous error
                                // Note: error clearing would need to be added to Camera protocol
                                _ = await camera.enableMultiCam()
                            }
                        } label: {
                            Label("Retry Dual Mode", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }


            // Layout options (always shown to allow pre-selection)
            if !camera.isRunningOnSimulator {
                Section("Preview Layout") {
                    ForEach(MultiCameraConfiguration.MultiCamLayout.allCases, id: \.self) { layout in
                        Button {
                            Task {
                                if !camera.isRunningOnSimulator && !camera.isMultiCamActive && camera.isMultiCamSupported {
                                    _ = await camera.enableMultiCam()
                                }
                                camera.multiCamLayout = layout
                            }
                        } label: {
                            HStack {
                                Image(systemName: layoutIcon(for: layout))
                                Text(layoutName(for: layout))
                                Spacer()
                                if camera.multiCamLayout == layout {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // Info section
            Section {
                if camera.isRunningOnSimulator {
                    Label("Test on Real Device", systemImage: "iphone")
                        .foregroundColor(.orange)
                } else if camera.isMultiCamActive {
                    Label("Dual Camera Recording", systemImage: "info.circle")
                } else {
                    Label("About Multi-Camera", systemImage: "info.circle")
                }
            }
        } label: {
            Image(systemName: camera.isMultiCamActive ? "video.fill.badge.checkmark" :
                  camera.isRunningOnSimulator ? "exclamationmark.triangle" : "video.badge.plus")
                .foregroundColor(camera.isMultiCamActive ? .blue :
                                camera.isRunningOnSimulator ? .orange : .white)
        }
        .disabled(camera.captureActivity.isRecording)
    }

    // Helper functions for layout display
    private func layoutName(for layout: MultiCameraConfiguration.MultiCamLayout) -> String {
        switch layout {
        case .pictureInPicture:
            return "Picture in Picture"
        case .sideBySide:
            return "Side by Side"
        case .grid:
            return "Grid"
        case .custom:
            return "Custom"
        }
    }

    private func layoutIcon(for layout: MultiCameraConfiguration.MultiCamLayout) -> String {
        switch layout {
        case .pictureInPicture:
            return "rectangle.inset.filled"
        case .sideBySide:
            return "rectangle.split.2x1"
        case .grid:
            return "square.grid.2x2"
        case .custom:
            return "rectangle.stack"
        }
    }
}
