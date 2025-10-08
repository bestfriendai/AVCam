/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Supporting data types for the app.
*/

@preconcurrency import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera.
enum CameraStatus {
    /// The initial status upon creation.
    case unknown
    /// A status that indicates a person disallows access to the camera or microphone.
    case unauthorized
    /// A status that indicates the camera failed to start.
    case failed
    /// A status that indicates the camera is successfully running.
    case running
    /// A status that indicates higher-priority media processing is interrupting the camera.
    case interrupted
}

/// An enumeration that defines the activity states the capture service supports.
///
/// This type provides feedback to the UI regarding the active status of the `CaptureService` actor.
enum CaptureActivity {
    case idle
    /// A status that indicates the capture service is performing photo capture.
    case photoCapture(willCapture: Bool = false, isLivePhoto: Bool = false)
    /// A status that indicates the capture service is performing movie capture.
    case movieCapture(duration: TimeInterval = 0.0)
    
    var isLivePhoto: Bool {
        if case .photoCapture(_, let isLivePhoto) = self {
            return isLivePhoto
        }
        return false
    }
    
    var willCapture: Bool {
        if case .photoCapture(let willCapture, _) = self {
            return willCapture
        }
        return false
    }
    
    var currentTime: TimeInterval {
        if case .movieCapture(let duration) = self {
            return duration
        }
        return .zero
    }
    
    var isRecording: Bool {
        if case .movieCapture(_) = self {
            return true
        }
        return false
    }
}

/// An enumeration of the capture modes that the camera supports.
enum CaptureMode: String, Identifiable, CaseIterable, Codable {
    var id: Self { self }
    /// A mode that enables photo capture.
    case photo
    /// A mode that enables video capture.
    case video
    
    var systemName: String {
        switch self {
        case .photo:
            "camera.fill"
        case .video:
            "video.fill"
        }
    }
}

/// A structure that represents a captured photo.
struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
    let livePhotoMovieURL: URL?
}

/// A structure that contains the uniform type identifier and movie URL.
struct Movie: Sendable {
    /// The primary temporary location of the file on disk.
    let url: URL
    /// An optional companion movie when recording multiple simultaneous feeds.
    let companionURL: URL?

    init(url: URL, companionURL: URL? = nil) {
        self.url = url
        self.companionURL = companionURL
    }

    /// Returns all file URLs associated with this capture.
    var allURLs: [URL] {
        if let companionURL {
            return [url, companionURL]
        }
        return [url]
    }
}

/// Describes a multi-camera preview configuration that drives dual-camera UI.
struct MultiCamPreviewConfiguration: @unchecked Sendable {
    let session: AVCaptureMultiCamSession
    let primaryPort: AVCaptureInput.Port
    let secondaryPort: AVCaptureInput.Port
}

struct PhotoFeatures {
    let isLivePhotoEnabled: Bool
    let qualityPrioritization: QualityPrioritization
}

/// A structure that represents the capture capabilities of `CaptureService` in
/// its current configuration.
struct CaptureCapabilities {

    let isLivePhotoCaptureSupported: Bool
    let isHDRSupported: Bool
    
    init(isLivePhotoCaptureSupported: Bool = false,
         isHDRSupported: Bool = false) {
        self.isLivePhotoCaptureSupported = isLivePhotoCaptureSupported
        self.isHDRSupported = isHDRSupported
    }
    
    static let unknown = CaptureCapabilities()
}

enum QualityPrioritization: Int, Identifiable, CaseIterable, CustomStringConvertible, Codable {
    var id: Self { self }
    case speed = 1
    case balanced
    case quality
    var description: String {
        switch self {
        case.speed:
            return "Speed"
        case .balanced:
            return "Balanced"
        case .quality:
            return "Quality"
        }
    }
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case audioDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
    case deviceChangeFailed
    case multiCamConfigurationFailed
    case cinematicVideoNotSupported
    case spatialVideoNotSupported
    case insufficientResources
    case thermalThrottling
    case externalCameraConnectionFailed
}

// MARK: - Enhanced Capture Features

/// Performance metrics for monitoring capture quality and system resources.
struct PerformanceMetrics: Sendable {
    let frameRate: Double
    let cpuUsage: Double
    let memoryUsage: UInt64
    let thermalState: ProcessInfo.ThermalState
    let batteryLevel: Float?
    let timestamp: Date
    
    static let unknown = PerformanceMetrics(
        frameRate: 0.0,
        cpuUsage: 0.0,
        memoryUsage: 0,
        thermalState: .nominal,
        batteryLevel: nil,
        timestamp: Date()
    )
}

/// Configuration for cinematic video capture.
struct CinematicVideoConfiguration: Sendable, Codable {
    let isEnabled: Bool
    let focusMode: CinematicFocusMode
    let simulatedAperture: Float
    
    enum CinematicFocusMode: String, CaseIterable, Codable {
        case none = "none"
        case weak = "weak"
        case strong = "strong"
    }
    
    static let `default` = CinematicVideoConfiguration(
        isEnabled: false,
        focusMode: .strong,
        simulatedAperture: 2.8
    )
}

/// Configuration for spatial video recording.
struct SpatialVideoConfiguration: Sendable, Codable {
    let isEnabled: Bool
    let depthDataEnabled: Bool
    let multiviewHEVC: Bool
    
    static let `default` = SpatialVideoConfiguration(
        isEnabled: false,
        depthDataEnabled: true,
        multiviewHEVC: true
    )
}

/// Multi-camera device configuration for advanced setups.
struct MultiCameraConfiguration: @unchecked Sendable, Codable {
    let deviceIDs: [String] // Store device IDs instead of actual devices
    let primaryDeviceID: String
    let layout: MultiCamLayout
    let synchronizationEnabled: Bool
    
    enum MultiCamLayout: String, CaseIterable, Codable {
        case pictureInPicture = "pip"
        case sideBySide = "sidebyside"
        case grid = "grid"
        case custom = "custom"
    }
    
    // Runtime properties (not Codable) - excluded from encoding/decoding
    private var _devices: [AVCaptureDevice] = []
    private var _primaryDevice: AVCaptureDevice?
    
    var devices: [AVCaptureDevice] {
        get { _devices }
        set { _devices = newValue }
    }
    
    var primaryDevice: AVCaptureDevice? {
        get { _primaryDevice }
        set { _primaryDevice = newValue }
    }
    
    // Custom coding to exclude runtime properties
    enum CodingKeys: String, CodingKey {
        case deviceIDs, primaryDeviceID, layout, synchronizationEnabled
    }
    
    // Custom initializer for creating configurations
    init(deviceIDs: [String], primaryDeviceID: String, layout: MultiCamLayout, synchronizationEnabled: Bool) {
        self.deviceIDs = deviceIDs
        self.primaryDeviceID = primaryDeviceID
        self.layout = layout
        self.synchronizationEnabled = synchronizationEnabled
    }
}

/// Stream information for multi-camera coordination.
struct VideoStream: @unchecked Sendable {
    let id: UUID
    let device: AVCaptureDevice
    let input: AVCaptureDeviceInput
    let output: AVCaptureOutput
    let isActive: Bool
    let priority: StreamPriority
    
    enum StreamPriority: Int, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2
    }
}

protocol OutputService {
    associatedtype Output: AVCaptureOutput
    var output: Output { get }
    var captureActivity: CaptureActivity { get }
    var capabilities: CaptureCapabilities { get }
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension OutputService {
    func setVideoRotationAngle(_ angle: CGFloat) {
        // Set the rotation angle on the output object's video connection.
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    func updateConfiguration(for device: AVCaptureDevice) {}
}
