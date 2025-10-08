/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Interactive onboarding flows for new features with engaging tutorials.
*/

import SwiftUI

// MARK: - Onboarding Manager

class OnboardingManager: ObservableObject {
    @Published var currentStep = 0
    @Published var isOnboardingComplete = false
    @Published var showOnboarding = false
    
    private let totalSteps = 6
    
    func startOnboarding() {
        currentStep = 0
        isOnboardingComplete = false
        showOnboarding = true
    }
    
    func nextStep() {
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep -= 1
            }
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        withAnimation {
            isOnboardingComplete = true
            showOnboarding = false
        }
        
        // Save onboarding completion
        UserDefaults.standard.set(true, forKey: "OnboardingComplete")
    }
    
    func shouldShowOnboarding() -> Bool {
        !UserDefaults.standard.bool(forKey: "OnboardingComplete")
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content area
                TabView(selection: $onboardingManager.currentStep) {
                    ForEach(0..<onboardingManager.totalSteps, id: \.self) { step in
                        onboardingStepView(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: onboardingManager.currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .padding()
        }
    }
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<onboardingManager.totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= onboardingManager.currentStep ? Color.blue : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == onboardingManager.currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: onboardingManager.currentStep)
            }
        }
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private func onboardingStepView(for step: Int) -> some View {
        switch step {
        case 0:
            WelcomeStep()
        case 1:
            CameraBasicsStep()
        case 2:
            MultiCamStep()
        case 3:
            AdvancedControlsStep()
        case 4:
            AccessibilityStep()
        case 5:
            PermissionsStep()
        default:
            EmptyView()
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            // Skip button
            if onboardingManager.currentStep < onboardingManager.totalSteps - 1 {
                Button("Skip") {
                    onboardingManager.skipOnboarding()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            } else {
                Button("Back") {
                    onboardingManager.previousStep()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Next/Get Started button
            Button {
                onboardingManager.nextStep()
            } label: {
                HStack {
                    Text(onboardingManager.currentStep == onboardingManager.totalSteps - 1 ? "Get Started" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if onboardingManager.currentStep < onboardingManager.totalSteps - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                )
            }
        }
        .padding(.top, 30)
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            // App icon
            Image(systemName: "camera.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            
            // Welcome text
            VStack(spacing: 16) {
                Text("Welcome to AVCam")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Experience the future of mobile photography with advanced multi-camera capabilities, professional controls, and intelligent features.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Feature highlights
            VStack(spacing: 12) {
                FeatureHighlight(icon: "camera.metering.multi.spot", title: "Multi-Camera", description: "Simultaneous dual camera recording")
                FeatureHighlight(icon: "slider.horizontal.3", title: "Pro Controls", description: "Manual exposure, focus, and white balance")
                FeatureHighlight(icon: "accessibility", title: "Accessible", description: "Voice control and enhanced accessibility")
            }
        }
        .padding()
    }
}

// MARK: - Camera Basics Step

struct CameraBasicsStep: View {
    var body: some View {
        VStack(spacing: 30) {
            // Camera interface preview
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    VStack(spacing: 20) {
                        // Mock camera preview
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Text("Camera Preview")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 60, height: 60)
                                        Spacer()
                                    }
                                    .padding(.bottom, 20)
                                }
                            )
                        
                        // Control hints
                        HStack(spacing: 30) {
                            ControlHint(icon: "camera", label: "Capture")
                            ControlHint(icon: "camera.rotate", label: "Switch")
                            ControlHint(icon: "photo", label: "Gallery")
                        }
                    }
                    .padding()
                )
            
            // Instructions
            VStack(spacing: 16) {
                Text("Camera Basics")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Learn the essential camera controls and gestures to capture stunning photos and videos.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Gesture guide
            VStack(spacing: 12) {
                GestureGuide(icon: "hand.tap", title: "Tap to Focus", description: "Tap anywhere to focus and expose")
                GestureGuide(icon: "hand.draw", title: "Swipe to Switch", description: "Swipe left or right to change modes")
                GestureGuide(icon: "hand.pinch", title: "Pinch to Zoom", description: "Pinch to zoom in and out")
            }
        }
        .padding()
    }
}

// MARK: - Multi-Camera Step

struct MultiCamStep: View {
    var body: some View {
        VStack(spacing: 30) {
            // Multi-cam preview
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 250)
                
                VStack(spacing: 10) {
                    // Main preview
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 150)
                        .overlay(
                            Text("Main Camera")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        )
                    
                    // Secondary preview
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 80, height: 60)
                            .overlay(
                                Text("Secondary")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .padding()
            }
            
            // Content
            VStack(spacing: 16) {
                Text("Multi-Camera Magic")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Record from multiple cameras simultaneously with picture-in-picture, split-screen, and overlay layouts.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Layout options
            HStack(spacing: 20) {
                LayoutOption(icon: "rectangle.inset.filled", title: "PiP")
                LayoutOption(icon: "rectangle.split.2x1", title: "Split")
                LayoutOption(icon: "rectangle.stack", title: "Overlay")
            }
        }
        .padding()
    }
}

// MARK: - Advanced Controls Step

struct AdvancedControlsStep: View {
    var body: some View {
        VStack(spacing: 30) {
            // Controls preview
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    VStack(spacing: 15) {
                        // Mock sliders
                        ForEach(0..<3) { index in
                            HStack {
                                Image(systemName: ["sun.max", "camera.metering.spot", "circle.lefthalf.filled"][index])
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 20)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: 60, alignment: .leading)
                                    )
                            }
                        }
                    }
                    .padding()
                )
            
            VStack(spacing: 16) {
                Text("Professional Controls")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Take full control with manual exposure, focus, white balance, ISO, and shutter speed adjustments.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Control features
            VStack(spacing: 12) {
                ControlFeature(icon: "sun.max.fill", title: "Exposure Control", description: "Adjust brightness and exposure bias")
                ControlFeature(icon: "camera.metering.spot", title: "Manual Focus", description: "Precise focus control")
                ControlFeature(icon: "circle.lefthalf.filled", title: "White Balance", description: "Custom color temperature")
            }
        }
        .padding()
    }
}

// MARK: - Accessibility Step

struct AccessibilityStep: View {
    var body: some View {
        VStack(spacing: 30) {
            // Accessibility icon
            Image(systemName: "accessibility")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            
            VStack(spacing: 16) {
                Text("Designed for Everyone")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Experience AVCam with comprehensive accessibility features including VoiceOver support, voice commands, and adaptive interfaces.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Accessibility features
            VStack(spacing: 12) {
                AccessibilityFeature(icon: "speaker.wave.3.fill", title: "Voice Control", description: "Control camera with voice commands")
                AccessibilityFeature(icon: "eye.fill", title: "VoiceOver Support", description: "Complete screen reader support")
                AccessibilityFeature(icon: "hand.tap.fill", title: "Adaptive Gestures", description: "Customizable interaction methods")
            }
        }
        .padding()
    }
}

// MARK: - Permissions Step

struct PermissionsStep: View {
    @State private var cameraPermission = false
    @State private var microphonePermission = false
    @State private var photoLibraryPermission = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Permissions icon
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            
            VStack(spacing: 16) {
                Text("Permissions Required")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("AVCam needs access to your camera, microphone, and photo library to provide the best experience.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Permission items
            VStack(spacing: 16) {
                PermissionItem(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Access to capture photos and videos",
                    isGranted: cameraPermission
                ) {
                    requestCameraPermission()
                }
                
                PermissionItem(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Record audio with videos",
                    isGranted: microphonePermission
                ) {
                    requestMicrophonePermission()
                }
                
                PermissionItem(
                    icon: "photo.fill",
                    title: "Photo Library",
                    description: "Save and access your media",
                    isGranted: photoLibraryPermission
                ) {
                    requestPhotoLibraryPermission()
                }
            }
        }
        .padding()
    }
    
    private func requestCameraPermission() {
        // Request camera permission
        cameraPermission = true
    }
    
    private func requestMicrophonePermission() {
        // Request microphone permission
        microphonePermission = true
    }
    
    private func requestPhotoLibraryPermission() {
        // Request photo library permission
        photoLibraryPermission = true
    }
}

// MARK: - Supporting Components

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct ControlHint: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct GestureGuide: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct LayoutOption: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                )
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct ControlFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct AccessibilityFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isGranted ? .green : .white.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.2) : Color.white.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else {
                Button("Allow") {
                    onRequest()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    OnboardingView()
}