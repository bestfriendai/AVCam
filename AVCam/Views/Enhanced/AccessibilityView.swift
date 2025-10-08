/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Enhanced accessibility features with VoiceOver, Dynamic Type, and inclusive design.
*/

import SwiftUI
import AVFoundation

// MARK: - Accessibility Manager

struct AccessibilityManager: ViewModifier {
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("largeText") private var largeText = false
    @AppStorage("voiceOverEnabled") private var voiceOverEnabled = false
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? .none : .default, value: UUID())
            .environment(\.colorScheme, highContrast ? .dark : .light)
            .dynamicTypeSize(largeText ? .accessibility1 : .large)
            .accessibilityAddTraits(voiceOverEnabled ? .isButton : [])
    }
}

// MARK: - Enhanced Camera Controls with Accessibility

struct AccessibleCameraControls<CameraModel: Camera>: View {
    @State var camera: CameraModel
    @State private var isVoiceControlActive = false
    @State private var selectedVoiceCommand: VoiceCommand? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // Voice control indicator
            if isVoiceControlActive {
                voiceControlIndicator
            }
            
            // Main controls with enhanced accessibility
            HStack(spacing: 30) {
                AccessibleCaptureButton(camera: camera)
                AccessibleSwitchCameraButton(camera: camera)
                AccessibleThumbnailButton(camera: camera)
            }
            
            // Voice command shortcuts
            voiceCommandShortcuts
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Camera controls")
        )
    }
    
    private var voiceControlIndicator: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.green)
                .scaleEffect(isVoiceControlActive ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isVoiceControlActive)
            
            Text("Voice Control Active")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.green.opacity(0.2))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice control is active")
        .accessibilityHint("Say commands to control the camera")
    }
    
    private var voiceCommandShortcuts: some View {
        VStack(spacing: 8) {
            Text("Voice Commands")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .accessibilityAddTraits(.isHeader)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(VoiceCommand.allCases, id: \.self) { command in
                    VoiceCommandButton(command: command, isSelected: selectedVoiceCommand == command) {
                        selectedVoiceCommand = command
                        executeVoiceCommand(command)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func executeVoiceCommand(_ command: VoiceCommand) {
        Task {
            switch command {
            case .capturePhoto:
                await camera.capturePhoto()
            case .startRecording:
                await camera.startRecording()
            case .stopRecording:
                await camera.stopRecording()
            case .switchCamera:
                await camera.switchCamera()
            case .toggleLivePhoto:
                camera.isLivePhotoEnabled.toggle()
            case .enableHDR:
                camera.isHDRVideoEnabled = true
            }
        }
    }
}

// MARK: - Accessible Capture Button

struct AccessibleCaptureButton<CameraModel: Camera>: View {
    @State var camera: CameraModel
    @State private var isPressed = false
    
    var body: some View {
        Button {
            Task {
                if camera.captureMode == .photo {
                    await camera.capturePhoto()
                } else {
                    await camera.toggleRecording()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(camera.captureMode == .photo ? Color.white : Color.red)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                
                if camera.captureMode == .video && camera.captureActivity.isRecording {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .accessibilityLabel(camera.captureMode == .photo ? "Capture photo" : (camera.captureActivity.isRecording ? "Stop recording" : "Start recording"))
        .accessibilityHint(camera.captureMode == .photo ? "Double tap to take a photo" : (camera.captureActivity.isRecording ? "Double tap to stop recording" : "Double tap to start recording"))
        .accessibilityAddTraits(.isButton)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Accessible Switch Camera Button

struct AccessibleSwitchCameraButton<CameraModel: Camera>: View {
    @State var camera: CameraModel
    
    var body: some View {
        Button {
            Task {
                await camera.switchCamera()
            }
        } label: {
            Image(systemName: "camera.rotate")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
        }
        .accessibilityLabel("Switch camera")
        .accessibilityHint("Double tap to switch between front and back camera")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessible Thumbnail Button

struct AccessibleThumbnailButton<CameraModel: Camera>: View {
    @State var camera: CameraModel
    
    var body: some View {
        Button {
            // Open photo library
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )
        }
        .accessibilityLabel("Photo library")
        .accessibilityHint("Double tap to open photo library")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Voice Command Button

struct VoiceCommandButton: View {
    let command: VoiceCommand
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: command.icon)
                    .font(.system(size: 14))
                Text(command.title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
            )
        }
        .accessibilityLabel(command.title)
        .accessibilityHint(command.hint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Voice Commands

enum VoiceCommand: CaseIterable {
    case capturePhoto
    case startRecording
    case stopRecording
    case switchCamera
    case toggleLivePhoto
    case enableHDR
    
    var title: String {
        switch self {
        case .capturePhoto: return "Capture"
        case .startRecording: return "Record"
        case .stopRecording: return "Stop"
        case .switchCamera: return "Switch"
        case .toggleLivePhoto: return "Live"
        case .enableHDR: return "HDR"
        }
    }
    
    var icon: String {
        switch self {
        case .capturePhoto: return "camera"
        case .startRecording: return "record.circle"
        case .stopRecording: return "stop.circle"
        case .switchCamera: return "camera.rotate"
        case .toggleLivePhoto: return "livephoto"
        case .enableHDR: return "video.badge.checkmark"
        }
    }
    
    var hint: String {
        switch self {
        case .capturePhoto: return "Take a photo"
        case .startRecording: return "Start video recording"
        case .stopRecording: return "Stop video recording"
        case .switchCamera: return "Switch camera"
        case .toggleLivePhoto: return "Toggle Live Photo"
        case .enableHDR: return "Enable HDR video"
        }
    }
}

// MARK: - Haptic Feedback Manager

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Audio Descriptions

struct AudioDescriptionManager {
    static func provideDescription(for element: AccessibilityElement) -> String {
        switch element {
        case .captureButton:
            return "Capture button. Currently in \(currentCaptureMode()) mode."
        case .switchCamera:
            return "Switch camera button. Currently using \(currentCamera()) camera."
        case .settings:
            return "Settings button. Access camera settings and preferences."
        case .gallery:
            return "Gallery button. View captured photos and videos."
        }
    }
    
    private static func currentCaptureMode() -> String {
        // Return current capture mode
        return "photo"
    }
    
    private static func currentCamera() -> String {
        // Return current camera
        return "back"
    }
}

enum AccessibilityElement {
    case captureButton
    case switchCamera
    case settings
    case gallery
}

// MARK: - High Contrast Theme

struct HighContrastTheme {
    static let backgroundColor = Color.black
    static let foregroundColor = Color.white
    static let accentColor = Color.yellow
    static let buttonColor = Color.white
    static let buttonBackgroundColor = Color.black
    static let borderColor = Color.white
}

// MARK: - Large Text Support

extension View {
    func accessibleText() -> some View {
        self
            .font(.system(size: 16, weight: .medium, design: .default))
            .minimumScaleFactor(0.8)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Focus Management

struct FocusManager: ViewModifier {
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
    }
}

// MARK: - Gesture Accessibility

struct AccessibleGestureView: View {
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            .onLongPressGesture {
                onLongPress()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Camera preview")
            .accessibilityHint("Single tap to focus, double tap to capture, long press for options")
            .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

// MARK: - Camera Extensions for Accessibility

extension Camera {
    var isLivePhotoEnabled: Bool { false }
    var isHDRVideoEnabled: Bool { false }
    
    func toggleRecording() async {}
    func startRecording() async {}
    func stopRecording() async {}
    func switchCamera() async {}
}

#Preview {
    AccessibleCameraControls(camera: PreviewCameraModel())
        .modifier(AccessibilityManager())
}