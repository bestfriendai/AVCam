/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Comprehensive settings and configuration screens with modern design.
*/

import SwiftUI

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var showingResetAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                settingsTabSelector
                
                // Content area
                TabView(selection: $selectedTab) {
                    GeneralSettingsView()
                        .tag(SettingsTab.general)
                    
                    CameraSettingsView()
                        .tag(SettingsTab.camera)
                    
                    VideoSettingsView()
                        .tag(SettingsTab.video)
                    
                    PhotoSettingsView()
                        .tag(SettingsTab.photo)
                    
                    StorageSettingsView()
                        .tag(SettingsTab.storage)
                    
                    AccessibilitySettingsView()
                        .tag(SettingsTab.accessibility)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private var settingsTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                            
                            Text(tab.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func resetAllSettings() {
        // Reset all settings to defaults
    }
}

// MARK: - Settings Tabs

enum SettingsTab: CaseIterable {
    case general
    case camera
    case video
    case photo
    case storage
    case accessibility
    
    var title: String {
        switch self {
        case .general: return "General"
        case .camera: return "Camera"
        case .video: return "Video"
        case .photo: return "Photo"
        case .storage: return "Storage"
        case .accessibility: return "Accessibility"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .camera: return "camera"
        case .video: return "video"
        case .photo: return "photo"
        case .storage: return "externaldrive"
        case .accessibility: return "accessibility"
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("autoSaveToPhotos") private var autoSaveToPhotos = true
    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("enableSounds") private var enableSounds = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("language") private var selectedLanguage = "System"
    
    var body: some View {
        Form {
            Section("Saving") {
                Toggle("Auto-save to Photos", isOn: $autoSaveToPhotos)
            }
            
            Section("Interface") {
                Toggle("Show Grid", isOn: $showGrid)
                Toggle("Enable Sounds", isOn: $enableSounds)
                Toggle("Enable Haptics", isOn: $enableHaptics)
            }
            
            Section("Language") {
                Picker("Language", selection: $selectedLanguage) {
                    Text("System").tag("System")
                    Text("English").tag("English")
                    Text("Spanish").tag("Spanish")
                    Text("French").tag("French")
                    Text("German").tag("German")
                    Text("Japanese").tag("Japanese")
                    Text("Chinese").tag("Chinese")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("100")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Reset") {
                Button("Reset All Settings") {
                    // Reset action
                }
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Camera Settings

struct CameraSettingsView: View {
    @AppStorage("defaultCamera") private var defaultCamera = "Back"
    @AppStorage("mirrorFrontCamera") private var mirrorFrontCamera = true
    @AppStorage("enableMacroMode") private var enableMacroMode = true
    @AppStorage("enableNightMode") private var enableNightMode = true
    @AppStorage("enablePortraitMode") private var enablePortraitMode = true
    
    var body: some View {
        Form {
            Section("Camera Selection") {
                Picker("Default Camera", selection: $defaultCamera) {
                    Text("Back").tag("Back")
                    Text("Front").tag("Front")
                    Text("Wide").tag("Wide")
                    Text("Ultra Wide").tag("Ultra Wide")
                    Text("Telephoto").tag("Telephoto")
                }
            }
            
            Section("Camera Modes") {
                Toggle("Mirror Front Camera", isOn: $mirrorFrontCamera)
                Toggle("Enable Macro Mode", isOn: $enableMacroMode)
                Toggle("Enable Night Mode", isOn: $enableNightMode)
                Toggle("Enable Portrait Mode", isOn: $enablePortraitMode)
            }
            
            Section("Focus & Exposure") {
                NavigationLink("Focus Settings") {
                    FocusSettingsView()
                }
                
                NavigationLink("Exposure Settings") {
                    ExposureSettingsView()
                }
                
                NavigationLink("White Balance") {
                    WhiteBalanceSettingsView()
                }
            }
            
            Section("Advanced") {
                NavigationLink("Manual Controls") {
                    ManualControlsView()
                }
                
                NavigationLink("Custom Presets") {
                    CustomPresetsView()
                }
            }
        }
    }
}

// MARK: - Video Settings

struct VideoSettingsView: View {
    @AppStorage("videoResolution") private var videoResolution = "1080p"
    @AppStorage("videoFrameRate") private var videoFrameRate = "30"
    @AppStorage("videoCodec") private var videoCodec = "H.264"
    @AppStorage("enableVideoStabilization") private var enableVideoStabilization = true
    @AppStorage("enableHDR") private var enableHDR = false
    @AppStorage("enableCinematicMode") private var enableCinematicMode = false
    
    var body: some View {
        Form {
            Section("Quality") {
                Picker("Resolution", selection: $videoResolution) {
                    Text("4K").tag("4K")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                }
                
                Picker("Frame Rate", selection: $videoFrameRate) {
                    Text("60 fps").tag("60")
                    Text("30 fps").tag("30")
                    Text("24 fps").tag("24")
                }
                
                Picker("Codec", selection: $videoCodec) {
                    Text("H.264").tag("H.264")
                    Text("HEVC").tag("HEVC")
                    Text("ProRes").tag("ProRes")
                }
            }
            
            Section("Features") {
                Toggle("Video Stabilization", isOn: $enableVideoStabilization)
                Toggle("HDR Video", isOn: $enableHDR)
                Toggle("Cinematic Mode", isOn: $enableCinematicMode)
            }
            
            Section("Audio") {
                NavigationLink("Audio Settings") {
                    AudioSettingsView()
                }
            }
            
            Section("Multi-Cam") {
                NavigationLink("Multi-Camera Setup") {
                    MultiCamSettingsView()
                }
            }
        }
    }
}

// MARK: - Photo Settings

struct PhotoSettingsView: View {
    @AppStorage("photoFormat") private var photoFormat = "HEIF"
    @AppStorage("enableLivePhoto") private var enableLivePhoto = true
    @AppStorage("enableSmartHDR") private var enableSmartHDR = true
    @AppStorage("enableDeepFusion") private var enableDeepFusion = true
    @AppStorage("enableNightMode") private var enableNightMode = true
    @AppStorage("enablePortraitMode") private var enablePortraitMode = true
    @AppStorage("burstModeSpeed") private var burstModeSpeed = "10"
    
    var body: some View {
        Form {
            Section("Format") {
                Picker("Photo Format", selection: $photoFormat) {
                    Text("HEIF").tag("HEIF")
                    Text("JPEG").tag("JPEG")
                    Text("RAW").tag("RAW")
                    Text("RAW + JPEG").tag("RAW + JPEG")
                }
            }
            
            Section("Features") {
                Toggle("Live Photos", isOn: $enableLivePhoto)
                Toggle("Smart HDR", isOn: $enableSmartHDR)
                Toggle("Deep Fusion", isOn: $enableDeepFusion)
                Toggle("Night Mode", isOn: $enableNightMode)
                Toggle("Portrait Mode", isOn: $enablePortraitMode)
            }
            
            Section("Burst Mode") {
                Picker("Burst Speed", selection: $burstModeSpeed) {
                    Text("10 fps").tag("10")
                    Text("5 fps").tag("5")
                    Text("3 fps").tag("3")
                }
            }
            
            Section("Filters") {
                NavigationLink("Photo Filters") {
                    PhotoFiltersView()
                }
            }
        }
    }
}

// MARK: - Storage Settings

struct StorageSettingsView: View {
    @State private var usedStorage: Double = 2.5
    @State private var totalStorage: Double = 128.0
    @AppStorage("autoDeleteOldMedia") private var autoDeleteOldMedia = false
    @AppStorage("maxStorageUsage") private var maxStorageUsage = 80.0
    
    var body: some View {
        Form {
            Section("Storage Usage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text("\(String(format: "%.1f", usedStorage)) GB")
                    }
                    
                    ProgressView(value: usedStorage / totalStorage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    HStack {
                        Text("Available")
                        Spacer()
                        Text("\(String(format: "%.1f", totalStorage - usedStorage)) GB")
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Management") {
                Toggle("Auto-delete Old Media", isOn: $autoDeleteOldMedia)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Storage Usage: \(Int(maxStorageUsage))%")
                    Slider(value: $maxStorageUsage, in: 50...95, step: 5)
                }
            }
            
            Section("Cache") {
                Button("Clear Cache") {
                    clearCache()
                }
                
                Button("Clear All Media") {
                    clearAllMedia()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private func clearCache() {
        // Clear cache implementation
    }
    
    private func clearAllMedia() {
        // Clear all media implementation
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettingsView: View {
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("largeText") private var largeText = false
    @AppStorage("voiceOver") private var voiceOver = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("audioDescriptions") private var audioDescriptions = false
    
    var body: some View {
        Form {
            Section("Vision") {
                Toggle("Reduce Motion", isOn: $reduceMotion)
                Toggle("High Contrast", isOn: $highContrast)
                Toggle("Large Text", isOn: $largeText)
                Toggle("VoiceOver", isOn: $voiceOver)
            }
            
            Section("Interaction") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
                
                NavigationLink("Touch Accommodations") {
                    TouchAccommodationsView()
                }
            }
            
            Section("Media") {
                Toggle("Audio Descriptions", isOn: $audioDescriptions)
                
                NavigationLink("Closed Captions") {
                    ClosedCaptionsView()
                }
            }
            
            Section("Voice Control") {
                NavigationLink("Voice Commands") {
                    VoiceCommandsView()
                }
            }
        }
    }
}

// MARK: - Placeholder Sub-Views

struct FocusSettingsView: View {
    var body: some View {
        Form {
            Text("Focus settings configuration")
        }
    }
}

struct ExposureSettingsView: View {
    var body: some View {
        Form {
            Text("Exposure settings configuration")
        }
    }
}

struct WhiteBalanceSettingsView: View {
    var body: some View {
        Form {
            Text("White balance settings configuration")
        }
    }
}

struct ManualControlsView: View {
    var body: some View {
        Form {
            Text("Manual controls configuration")
        }
    }
}

struct CustomPresetsView: View {
    var body: some View {
        Form {
            Text("Custom presets configuration")
        }
    }
}

struct AudioSettingsView: View {
    var body: some View {
        Form {
            Text("Audio settings configuration")
        }
    }
}

struct MultiCamSettingsView: View {
    var body: some View {
        Form {
            Text("Multi-camera settings configuration")
        }
    }
}

struct PhotoFiltersView: View {
    var body: some View {
        Form {
            Text("Photo filters configuration")
        }
    }
}

struct TouchAccommodationsView: View {
    var body: some View {
        Form {
            Text("Touch accommodations configuration")
        }
    }
}

struct ClosedCaptionsView: View {
    var body: some View {
        Form {
            Text("Closed captions configuration")
        }
    }
}

struct VoiceCommandsView: View {
    var body: some View {
        Form {
            Text("Voice commands configuration")
        }
    }
}

#Preview {
    SettingsView()
}