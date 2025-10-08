/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Advanced camera control interfaces with professional features.
*/

import SwiftUI
import AVFoundation

// MARK: - Advanced Control Panel

struct AdvancedControlPanel<CameraModel: Camera>: View {
    @State var camera: CameraModel
    @State private var expandedSection: ControlSection? = nil
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main control toggle
            HStack {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "slider.horizontal.3" : "slider.horizontal.3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                
                Spacer()
                
                Text("Advanced Controls")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    resetToDefaults()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .blur(radius: 1)
            )
            
            // Expanded controls
            if isExpanded {
                expandedControls
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    @ViewBuilder
    private var expandedControls: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                exposureControls
                focusControls
                whiteBalanceControls
                isoControls
                shutterSpeedControls
                apertureControls
                videoProfileControls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .blur(radius: 1)
        )
    }
    
    // MARK: - Exposure Controls
    
    private var exposureControls: some View {
        ControlSection(
            title: "Exposure",
            icon: "sun.max",
            isExpanded: expandedSection == .exposure
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Bias")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(formatExposureBias(camera.exposureTargetBias))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Slider(value: Binding(
                    get: { camera.exposureTargetBias },
                    set: { camera.setExposureTargetBias($0) }
                ), in: -2.0...2.0, step: 0.1)
                .accentColor(.orange)
                
                HStack {
                    Button("Auto") {
                        camera.resetExposureToAuto()
                    }
                    .buttonStyle(ControlButtonStyle())
                    
                    Button("Lock") {
                        camera.lockExposure()
                    }
                    .buttonStyle(ControlButtonStyle())
                }
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .exposure ? nil : .exposure
            }
        }
    }
    
    // MARK: - Focus Controls
    
    private var focusControls: some View {
        ControlSection(
            title: "Focus",
            icon: "camera.metering.spot",
            isExpanded: expandedSection == .focus
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Mode")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Picker("Focus Mode", selection: Binding(
                        get: { camera.focusMode },
                        set: { camera.setFocusMode($0) }
                    )) {
                        Text("Auto").tag(AVCaptureDevice.FocusMode.autoFocus)
                        Text("Manual").tag(AVCaptureDevice.FocusMode.manualFocus)
                        Text("Locked").tag(AVCaptureDevice.FocusMode.locked)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                
                if camera.focusMode == .manualFocus {
                    HStack {
                        Text("Distance")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(formatLensPosition(camera.lensPosition))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Slider(value: Binding(
                        get: { camera.lensPosition },
                        set: { camera.setLensPosition($0) }
                    ), in: 0.0...1.0)
                    .accentColor(.blue)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .focus ? nil : .focus
            }
        }
    }
    
    // MARK: - White Balance Controls
    
    private var whiteBalanceControls: some View {
        ControlSection(
            title: "White Balance",
            icon: "circle.lefthalf.filled",
            isExpanded: expandedSection == .whiteBalance
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Mode")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Picker("WB Mode", selection: Binding(
                        get: { camera.whiteBalanceMode },
                        set: { camera.setWhiteBalanceMode($0) }
                    )) {
                        Text("Auto").tag(AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance)
                        Text("Manual").tag(AVCaptureDevice.WhiteBalanceMode.locked)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                
                if camera.whiteBalanceMode == .locked {
                    HStack {
                        Text("Temperature")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(Int(camera.whiteBalanceTemperature))K")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Slider(value: Binding(
                        get: { camera.whiteBalanceTemperature },
                        set: { camera.setWhiteBalanceTemperature($0) }
                    ), in: 2000...8000, step: 100)
                    .accentColor(.yellow)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .whiteBalance ? nil : .whiteBalance
            }
        }
    }
    
    // MARK: - ISO Controls
    
    private var isoControls: some View {
        ControlSection(
            title: "ISO",
            icon: "camera.aperture",
            isExpanded: expandedSection == .iso
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Sensitivity")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("ISO \(Int(camera.iso))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Slider(value: Binding(
                    get: { camera.iso },
                    set: { camera.setISO($0) }
                ), in: camera.minISO...camera.maxISO)
                .accentColor(.purple)
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .iso ? nil : .iso
            }
        }
    }
    
    // MARK: - Shutter Speed Controls
    
    private var shutterSpeedControls: some View {
        ControlSection(
            title: "Shutter Speed",
            icon: "timer",
            isExpanded: expandedSection == .shutterSpeed
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Duration")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(formatShutterSpeed(camera.exposureDuration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Slider(value: Binding(
                    get: { log2(camera.exposureDuration.timescale) },
                    set: { camera.setExposureDuration(pow(2, $0)) }
                ), in: -10...0)
                .accentColor(.green)
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .shutterSpeed ? nil : .shutterSpeed
            }
        }
    }
    
    // MARK: - Video Profile Controls
    
    private var videoProfileControls: some View {
        ControlSection(
            title: "Video Profile",
            icon: "video.badge.checkmark",
            isExpanded: expandedSection == .videoProfile
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("Resolution")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Picker("Resolution", selection: Binding(
                        get: { camera.videoResolution },
                        set: { camera.setVideoResolution($0) }
                    )) {
                        Text("4K").tag(VideoResolution.uhd4K)
                        Text("1080p").tag(VideoResolution.hd1080)
                        Text("720p").tag(VideoResolution.hd720)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                
                HStack {
                    Text("Frame Rate")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Picker("Frame Rate", selection: Binding(
                        get: { camera.frameRate },
                        set: { camera.setFrameRate($0) }
                    )) {
                        Text("60").tag(60.0)
                        Text("30").tag(30.0)
                        Text("24").tag(24.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                expandedSection = expandedSection == .videoProfile ? nil : .videoProfile
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetToDefaults() {
        camera.resetExposureToAuto()
        camera.setFocusMode(.autoFocus)
        camera.setWhiteBalanceMode(.continuousAutoWhiteBalance)
        // Reset other controls to defaults
    }
    
    private func formatExposureBias(_ bias: Float) -> String {
        String(format: "%.1f EV", bias)
    }
    
    private func formatLensPosition(_ position: Float) -> String {
        String(format: "%.2f", position)
    }
    
    private func formatShutterSpeed(_ duration: CMTime) -> String {
        let seconds = CMTimeGetSeconds(duration)
        if seconds < 1 {
            return String(format: "1/%.0f", 1/seconds)
        } else {
            return String(format: "%.1fs", seconds)
        }
    }
}

// MARK: - Control Section Component

struct ControlSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let content: Content
    
    @State private var isAnimating = false
    
    init(title: String, icon: String, isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.isExpanded = isExpanded
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            
            if isExpanded {
                content
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Control Button Style

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Control Section Enum

enum ControlSection {
    case exposure
    case focus
    case whiteBalance
    case iso
    case shutterSpeed
    case videoProfile
}

// MARK: - Video Resolution Enum

enum VideoResolution {
    case uhd4K
    case hd1080
    case hd720
}

// MARK: - Camera Extensions for Advanced Controls

extension Camera {
    var exposureTargetBias: Float { 0.0 }
    var focusMode: AVCaptureDevice.FocusMode { .autoFocus }
    var lensPosition: Float { 0.5 }
    var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode { .continuousAutoWhiteBalance }
    var whiteBalanceTemperature: Float { 5000 }
    var iso: Float { 100 }
    var minISO: Float { 50 }
    var maxISO: Float { 3200 }
    var exposureDuration: CMTime { CMTime(value: 1, timescale: 60) }
    var videoResolution: VideoResolution { .hd1080 }
    var frameRate: Double { 30.0 }
    
    func setExposureTargetBias(_ bias: Float) {}
    func resetExposureToAuto() {}
    func lockExposure() {}
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {}
    func setLensPosition(_ position: Float) {}
    func setWhiteBalanceMode(_ mode: AVCaptureDevice.WhiteBalanceMode) {}
    func setWhiteBalanceTemperature(_ temperature: Float) {}
    func setISO(_ iso: Float) {}
    func setExposureDuration(_ duration: CMTime) {}
    func setVideoResolution(_ resolution: VideoResolution) {}
    func setFrameRate(_ frameRate: Double) {}
}

#Preview {
    AdvancedControlPanel(camera: PreviewCameraModel())
}