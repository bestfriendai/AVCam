/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that presents the main camera user interface.
*/

import SwiftUI
import AVFoundation

/// A view that presents the main camera user interface.
struct CameraUI<CameraModel: Camera>: PlatformView {

    @State var camera: CameraModel
    @Binding var swipeDirection: SwipeDirection
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        Group {
            if isRegularSize {
                regularUI
            } else {
                compactUI
            }
        }
        .overlay(alignment: .top) {
            switch camera.captureMode {
            case .photo:
                LiveBadge()
                    .opacity(camera.captureActivity.isLivePhoto ? 1.0 : 0.0)
            case .video:
                RecordingTimeView(time: camera.captureActivity.currentTime)
                    .offset(y: isRegularSize ? 20 : 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Show zoom toggle for video mode on rear camera
            if camera.captureMode == .video {
                ZoomToggleView(camera: camera)
                    .padding(12)
            }
        }
        .overlay {
            StatusOverlayView(status: camera.status)
        }
        .overlay(alignment: .bottom) {
            // Feedback banner
            if camera.feedback.isVisible, let message = camera.feedback.message {
                FeedbackBanner(message: message, type: camera.feedback.type)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: camera.feedback.isVisible)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Debug info overlay
            DebugInfoView(camera: camera)
        }
    }
    
    /// This view arranges UI elements vertically.
    @ViewBuilder
    var compactUI: some View {
        VStack(spacing: 0) {
            FeaturesToolbar(camera: camera)
            Spacer()
            CaptureModeView(camera: camera, direction: $swipeDirection)
            MainToolbar(camera: camera)
                .padding(.bottom, bottomPadding)
        }
    }
    
    /// This view arranges UI elements in a layered stack.
    @ViewBuilder
    var regularUI: some View {
        VStack {
            Spacer()
            ZStack {
                CaptureModeView(camera: camera, direction: $swipeDirection)
                    .offset(x: -250) // The vertical offset from center.
                MainToolbar(camera: camera)
                FeaturesToolbar(camera: camera)
                    .frame(width: 250)
                    .offset(x: 250) // The vertical offset from center.
            }
            .frame(width: 740)
            .background(.ultraThinMaterial.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 32)
        }
    }
    
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture the swipe direction.
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
    
    var bottomPadding: CGFloat {
        // Dynamically calculate the offset for the bottom toolbar in iOS.
        // Use a reasonable default based on standard screen sizes
        // This avoids the deprecated UIScreen.main
        let standardHeight: CGFloat = 844 // iPhone 14/15 Pro height
        let standardWidth: CGFloat = 390
        let bounds = CGRect(x: 0, y: 0, width: standardWidth, height: standardHeight)
        let rect = AVMakeRect(aspectRatio: movieAspectRatio, insideRect: bounds)
        return (rect.minY.rounded() / 2) + 12
    }
}

/// A view that displays quick-access zoom toggle buttons for the rear camera.
private struct ZoomToggleView<CameraModel: Camera>: View {

    @State var camera: CameraModel
    @State private var selectedZoom: RearZoomPreset = .wide_1x

    var body: some View {
        HStack(spacing: 8) {
            zoomButton(for: .ultraWide_0_5x, label: "0.5×")
            zoomButton(for: .wide_1x, label: "1×")
            zoomButton(for: .tele_2x, label: "2×")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func zoomButton(for preset: RearZoomPreset, label: String) -> some View {
        Button {
            selectedZoom = preset
            camera.setRearZoomPreset(preset)
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selectedZoom == preset ? .semibold : .regular))
                .foregroundColor(selectedZoom == preset ? .primary : .secondary)
                .frame(minWidth: 36)
        }
        .buttonStyle(.plain)
    }
}

/// Debug information overlay showing camera state
private struct DebugInfoView<CameraModel: Camera>: View {
    @State var camera: CameraModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Toggle button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "info.circle.fill")
                    if !isExpanded {
                        Text("Debug")
                    }
                }
                .font(.caption)
                .foregroundColor(.white)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("State: \(camera.sessionState.current.description)")
                        .foregroundColor(camera.sessionState.isDualCameraActive ? .green : .white)
                    Text("Multi-Cam: \(camera.isMultiCamActive ? "✅ Active" : "❌ Inactive")")
                    Text("Supported: \(camera.isMultiCamSupported ? "✅ Yes" : "❌ No")")
                    Text("Simulator: \(camera.isRunningOnSimulator ? "⚠️ Yes" : "✅ No")")
                    Text("Mode: \(camera.captureMode == .video ? "📹 Video" : "📷 Photo")")
                    Text("Layout: \(camera.multiCamLayout == .grid ? "Grid" : "PiP")")

                    if camera.sessionState.isTransitioning {
                        Divider()
                        Text("⏳ Transitioning...")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }

                    if camera.sessionState.hasError {
                        Divider()
                        Text("❌ \(camera.sessionState.current.description)")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }

                    if let error = camera.error {
                        Divider()
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                }
                .font(.caption.monospaced())
                .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(.black.opacity(0.7))
        .cornerRadius(8)
        .padding()
    }
}

#Preview {
    CameraUI(camera: PreviewCameraModel(), swipeDirection: .constant(.left))
}
