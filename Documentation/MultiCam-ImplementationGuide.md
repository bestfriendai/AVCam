# AVCam Multi-Camera Implementation Guide

## Overview

This guide provides detailed implementation instructions for upgrading AVCam to support multi-camera functionality. Each section includes code examples, best practices, and common pitfalls to avoid.

## Prerequisites

Before implementing multi-camera features, ensure you have:

- Xcode 15.0+
- iOS 15.0+ deployment target
- Physical device for testing (Simulator doesn't support multi-cam)
- Understanding of AVFoundation framework
- Familiarity with Swift concurrency

## 1. Multi-Camera Session Setup

### 1.1 Session Architecture

The multi-camera implementation requires replacing `AVCaptureSession` with `AVCaptureMultiCamSession`. Here's the enhanced session structure:

```swift
// CaptureService.swift - Enhanced for multi-camera
actor CaptureService {
    private let captureSession: AVCaptureSession
    private var multiCamSession: AVCaptureMultiCamSession? { 
        captureSession as? AVCaptureMultiCamSession 
    }
    
    // Multi-camera specific properties
    private var primaryVideoInput: AVCaptureDeviceInput?
    private var secondaryVideoInput: AVCaptureDeviceInput?
    private var tertiaryVideoInputs: [AVCaptureDeviceInput] = []
    
    // Output services for each stream
    private let primaryPhotoCapture = PhotoCapture()
    private let primaryMovieCapture = MovieCapture()
    private let secondaryMovieCapture = MovieCapture()
    
    init() {
        if AVCaptureMultiCamSession.isMultiCamSupported {
            captureSession = AVCaptureMultiCamSession()
        } else {
            captureSession = AVCaptureSession()
        }
    }
}
```

### 1.2 Device Discovery Enhancement

Enhance the `DeviceLookup` class to support multi-camera scenarios:

```swift
// DeviceLookup.swift - Multi-camera enhancements
final class DeviceLookup {
    // Existing discovery sessions
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let externalCameraDiscoverSession: AVCaptureDevice.DiscoverySession
    
    // New multi-camera discovery sessions
    private let ultraWideCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let telephotoCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    
    init() {
        // Existing sessions...
        
        // Multi-camera specific sessions
        ultraWideCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: .back
        )
        
        telephotoCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
    }
    
    // New methods for multi-camera support
    func getMultiCamDeviceSet() -> MultiCamDeviceSet? {
        guard let back = backCamera,
              let front = frontCamera else { return nil }
        
        var devices: [AVCaptureDevice] = [back, front]
        
        // Add ultra-wide if available
        if let ultraWide = ultraWideCameraDiscoverySession.devices.first {
            devices.append(ultraWide)
        }
        
        // Add telephoto if available
        if let telephoto = telephotoCameraDiscoverySession.devices.first {
            devices.append(telephoto)
        }
        
        return MultiCamDeviceSet(devices: devices)
    }
    
    func getOptimalDevicePair() -> (primary: AVCaptureDevice, secondary: AVCaptureDevice)? {
        guard let back = backCamera,
              let front = frontCamera else { return nil }
        
        // Check for triple camera system
        if let ultraWide = ultraWideCameraDiscoverySession.devices.first {
            return (back, ultraWide) // Back and ultra-wide for creative shots
        }
        
        return (back, front) // Default back and front
    }
}

// New data structures
struct MultiCamDeviceSet {
    let devices: [AVCaptureDevice]
    let primaryDevice: AVCaptureDevice
    let secondaryDevice: AVCaptureDevice
    
    init(devices: [AVCaptureDevice]) {
        self.devices = devices
        self.primaryDevice = devices.first { $0.position == .back } ?? devices.first!
        self.secondaryDevice = devices.first { $0.position == .front } ?? devices.last!
    }
}
```

### 1.3 Multi-Camera Session Configuration

```swift
// CaptureService.swift - Multi-camera setup
private func setUpMultiCamSession(session: AVCaptureMultiCamSession) throws {
    guard let deviceSet = deviceLookup.getMultiCamDeviceSet() else {
        throw CameraError.multiCamConfigurationFailed
    }
    
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    
    // Configure audio for high-quality recording
    session.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true
    
    // Configure formats for each device
    try configureMultiCamFormat(for: deviceSet.primaryDevice, role: .primary)
    try configureMultiCamFormat(for: deviceSet.secondaryDevice, role: .secondary)
    
    // Add inputs without automatic connections
    let primaryInput = try addInput(for: deviceSet.primaryDevice, connectAutomatically: false)
    let secondaryInput = try addInput(for: deviceSet.secondaryDevice, connectAutomatically: false)
    
    activeVideoInput = primaryInput
    secondaryVideoInput = secondaryInput
    
    // Add audio input
    let audioInput = try addInput(for: deviceLookup.defaultMic)
    
    // Add outputs without automatic connections
    try addOutput(primaryPhotoCapture.output, connectAutomatically: false)
    try addOutput(primaryMovieCapture.output, connectAutomatically: false)
    try addOutput(secondaryMovieCapture.output, connectAutomatically: false)
    
    // Create explicit connections
    try createMultiCamConnections(
        session: session,
        primaryInput: primaryInput,
        secondaryInput: secondaryInput,
        audioInput: audioInput
    )
    
    // Configure device-specific settings
    configureControls(for: deviceSet.primaryDevice)
    createRotationCoordinator(for: deviceSet.primaryDevice)
    observeSubjectAreaChanges(of: deviceSet.primaryDevice)
    
    // Update capabilities and start monitoring
    updateCaptureCapabilities()
    observeSecondaryCaptureActivity()
}

private func configureMultiCamFormat(for device: AVCaptureDevice, role: StreamRole) throws {
    let supportedFormats = device.formats.filter { $0.isMultiCamSupported }
    
    let selectedFormat: AVCaptureDevice.Format
    switch role {
    case .primary:
        // Prioritize quality for primary stream
        selectedFormat = supportedFormats.max { lhs, rhs in
            compareFormatsForQuality(lhs, rhs)
        } ?? supportedFormats.first!
    case .secondary:
        // Balance quality and performance for secondary
        selectedFormat = supportedFormats.max { lhs, rhs in
            compareFormatsForBalanced(lhs, rhs)
        } ?? supportedFormats.first!
    }
    
    try device.lockForConfiguration()
    device.activeFormat = selectedFormat
    
    // Set optimal frame rate
    if let frameRateRange = selectedFormat.videoSupportedFrameRateRanges
        .sorted(by: { $0.maxFrameRate > $1.maxFrameRate }).first {
        device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
        device.activeVideoMaxFrameDuration = frameRateRange.maxFrameDuration
    }
    
    device.unlockForConfiguration()
}

private func createMultiCamConnections(
    session: AVCaptureMultiCamSession,
    primaryInput: AVCaptureDeviceInput,
    secondaryInput: AVCaptureDeviceInput,
    audioInput: AVCaptureDeviceInput
) throws {
    
    // Get video ports for each input
    guard let primaryVideoPort = primaryInput.ports(for: .video,
                                                   sourceDeviceType: primaryInput.device.deviceType,
                                                   sourceDevicePosition: primaryInput.device.position).first,
          let secondaryVideoPort = secondaryInput.ports(for: .video,
                                                       sourceDeviceType: secondaryInput.device.deviceType,
                                                       sourceDevicePosition: secondaryInput.device.position).first,
          let audioPort = audioInput.ports.first(where: { $0.mediaType == .audio }) else {
        throw CameraError.multiCamConfigurationFailed
    }
    
    // Connect photo output to primary camera
    let photoConnection = AVCaptureConnection(inputPorts: [primaryVideoPort], 
                                            output: primaryPhotoCapture.output)
    guard session.canAddConnection(photoConnection) else {
        throw CameraError.multiCamConfigurationFailed
    }
    session.addConnection(photoConnection)
    
    // Connect primary movie output
    let primaryMovieConnection = AVCaptureConnection(inputPorts: [primaryVideoPort, audioPort],
                                                   output: primaryMovieCapture.output)
    primaryMovieConnection.preferredVideoStabilizationMode = .auto
    guard session.canAddConnection(primaryMovieConnection) else {
        throw CameraError.multiCamConfigurationFailed
    }
    session.addConnection(primaryMovieConnection)
    
    // Connect secondary movie output
    let secondaryMovieConnection = AVCaptureConnection(inputPorts: [secondaryVideoPort],
                                                     output: secondaryMovieCapture.output)
    secondaryMovieConnection.preferredVideoStabilizationMode = .auto
    guard session.canAddConnection(secondaryMovieConnection) else {
        throw CameraError.multiCamConfigurationFailed
    }
    session.addConnection(secondaryMovieConnection)
    
    // Store configuration for preview
    multiCamPreviewConfiguration = MultiCamPreviewConfiguration(
        session: session,
        primaryPort: primaryVideoPort,
        secondaryPort: secondaryVideoPort
    )
}
```

## 2. Enhanced Preview System

### 2.1 Multi-Camera Preview View

```swift
// MultiCamPreview.swift - Enhanced implementation
struct MultiCamPreview: UIViewRepresentable {
    let configuration: MultiCamPreviewConfiguration
    let layout: MultiCamLayout
    
    func makeUIView(context: Context) -> MultiCamPreviewView {
        let view = MultiCamPreviewView()
        view.configure(with: configuration, layout: layout)
        return view
    }
    
    func updateUIView(_ uiView: MultiCamPreviewView, context: Context) {
        uiView.updateLayout(layout)
    }
}

final class MultiCamPreviewView: UIView {
    private var primaryLayer: AVCaptureVideoPreviewLayer?
    private var secondaryLayer: AVCaptureVideoPreviewLayer?
    private var tertiaryLayers: [AVCaptureVideoPreviewLayer] = []
    
    private weak var session: AVCaptureMultiCamSession?
    private var currentLayout: MultiCamLayout = .pip
    
    // Layout constraints
    private var primaryConstraints: [NSLayoutConstraint] = []
    private var secondaryConstraints: [NSLayoutConstraint] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        clipsToBounds = true
        backgroundColor = .black
    }
    
    func configure(with configuration: MultiCamPreviewConfiguration, layout: MultiCamLayout) {
        guard configuration.session != session else {
            updateLayout(layout)
            return
        }
        
        let session = configuration.session
        session.beginConfiguration()
        
        // Clean up existing layers
        cleanupLayers()
        
        self.session = session
        self.currentLayout = layout
        
        // Install preview layers
        installPrimaryLayer(using: session, port: configuration.primaryPort)
        installSecondaryLayer(using: session, port: configuration.secondaryPort)
        
        session.commitConfiguration()
        
        // Apply layout
        updateLayout(layout)
    }
    
    private func installPrimaryLayer(using session: AVCaptureMultiCamSession, port: AVCaptureInput.Port) {
        let layer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        layer.videoGravity = .resizeAspectFill
        layer.name = "primary"
        
        primaryLayer = layer
        layer.addSublayer(layer)
    }
    
    private func installSecondaryLayer(using session: AVCaptureMultiCamSession, port: AVCaptureInput.Port) {
        let layer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        layer.videoGravity = .resizeAspectFill
        layer.masksToBounds = true
        layer.cornerRadius = 12
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.borderWidth = 1
        layer.name = "secondary"
        
        secondaryLayer = layer
        layer.addSublayer(layer)
    }
    
    func updateLayout(_ layout: MultiCamLayout) {
        currentLayout = layout
        
        // Remove existing constraints
        NSLayoutConstraint.deactivate(primaryConstraints + secondaryConstraints)
        primaryConstraints.removeAll()
        secondaryConstraints.removeAll()
        
        switch layout {
        case .pip:
            applyPiPLayout()
        case .sideBySide:
            applySideBySideLayout()
        case .grid:
            applyGridLayout()
        case .custom(let config):
            applyCustomLayout(config)
        }
    }
    
    private func applyPiPLayout() {
        guard let primaryLayer = primaryLayer,
              let secondaryLayer = secondaryLayer else { return }
        
        // Primary layer fills entire view
        primaryLayer.frame = bounds
        
        // Secondary layer in corner
        let inset: CGFloat = 16
        let pipWidth: CGFloat = bounds.width * 0.3
        let pipHeight = pipWidth * (4.0 / 3.0)
        
        secondaryLayer.frame = CGRect(
            x: bounds.maxX - pipWidth - inset,
            y: inset,
            width: pipWidth,
            height: pipHeight
        )
    }
    
    private func applySideBySideLayout() {
        guard let primaryLayer = primaryLayer,
              let secondaryLayer = secondaryLayer else { return }
        
        let halfWidth = bounds.width / 2
        
        primaryLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: halfWidth,
            height: bounds.height
        )
        
        secondaryLayer.frame = CGRect(
            x: halfWidth,
            y: 0,
            width: halfWidth,
            height: bounds.height
        )
    }
    
    private func applyGridLayout() {
        // Implementation for 2x2 grid layout
        // Useful when supporting 3+ cameras
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(currentLayout)
    }
    
    private func cleanupLayers() {
        primaryLayer?.removeFromSuperlayer()
        secondaryLayer?.removeFromSuperlayer()
        tertiaryLayers.forEach { $0.removeFromSuperlayer() }
        
        primaryLayer = nil
        secondaryLayer = nil
        tertiaryLayers.removeAll()
    }
}

// Layout enumeration
enum MultiCamLayout {
    case pip
    case sideBySide
    case grid
    case custom(MultiCamLayoutConfig)
}

struct MultiCamLayoutConfig {
    let primaryFrame: CGRect
    let secondaryFrame: CGRect
    let tertiaryFrames: [CGRect]
}
```

## 3. Enhanced Camera Model

### 3.1 Multi-Camera State Management

```swift
// CameraModel.swift - Multi-camera enhancements
@MainActor
@Observable
final class CameraModel: Camera {
    // Existing properties...
    
    // Multi-camera specific properties
    private(set) var isMultiCamEnabled = false
    private(set) var activeCameras: [AVCaptureDevice] = []
    private(set) var multiCamLayout: MultiCamLayout = .pip
    private(set) var recordingStreams: Set<StreamIdentifier> = []
    
    // Stream management
    private let streamManager = MultiCamStreamManager()
    
    // Performance monitoring
    private let performanceMonitor = PerformanceMonitor()
    
    func enableMultiCam() async {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            error = CameraError.multiCamNotSupported
            return
        }
        
        isMultiCamEnabled = true
        
        // Restart capture service with multi-cam configuration
        if status == .running {
            await captureService.stop()
            try? await captureService.start(with: cameraState)
        }
    }
    
    func disableMultiCam() async {
        isMultiCamEnabled = false
        
        // Restart with single camera configuration
        if status == .running {
            await captureService.stop()
            try? await captureService.start(with: cameraState)
        }
    }
    
    func switchLayout(_ layout: MultiCamLayout) {
        multiCamLayout = layout
        // Notify preview view of layout change
    }
    
    func startMultiCamRecording() async {
        guard isMultiCamEnabled else { return }
        
        do {
            // Start recording on all configured streams
            try await streamManager.startRecordingOnAllStreams()
            recordingStreams = streamManager.activeStreamIds
        } catch {
            self.error = error
        }
    }
    
    func stopMultiCamRecording() async {
        do {
            let movies = try await streamManager.stopRecordingOnAllStreams()
            // Save all recorded movies
            for movie in movies {
                try await mediaLibrary.save(movie: movie)
            }
            recordingStreams.removeAll()
        } catch {
            self.error = error
        }
    }
}
```

## 4. Stream Management System

### 4.1 Multi-Camera Stream Manager

```swift
// MultiCamStreamManager.swift
actor MultiCamStreamManager {
    private var streams: [StreamIdentifier: VideoStream] = [:]
    private var activeRecordings: Set<StreamIdentifier> = []
    
    func addStream(_ stream: VideoStream) {
        streams[stream.id] = stream
    }
    
    func removeStream(id: StreamIdentifier) {
        streams.removeValue(forKey: id)
        activeRecordings.remove(id)
    }
    
    func startRecordingOnAllStreams() async throws {
        for (id, stream) in streams {
            try await stream.startRecording()
            activeRecordings.insert(id)
        }
    }
    
    func stopRecordingOnAllStreams() async throws -> [Movie] {
        var movies: [Movie] = []
        
        for id in activeRecordings {
            guard let stream = streams[id] else { continue }
            let movie = try await stream.stopRecording()
            movies.append(movie)
        }
        
        activeRecordings.removeAll()
        return movies
    }
    
    func getActiveStreamIds() -> Set<StreamIdentifier> {
        return activeRecordings
    }
}

// Video stream abstraction
class VideoStream {
    let id: StreamIdentifier
    let device: AVCaptureDevice
    let output: AVCaptureMovieFileOutput
    private var isRecording = false
    
    init(device: AVCaptureDevice, output: AVCaptureMovieFileOutput) {
        self.id = StreamIdentifier()
        self.device = device
        self.output = output
    }
    
    func startRecording() async throws {
        guard !isRecording else { return }
        
        let url = URL.movieFileURL
        output.startRecording(to: url, recordingDelegate: StreamRecordingDelegate())
        isRecording = true
    }
    
    func stopRecording() async throws -> Movie {
        guard isRecording else { throw CameraError.notRecording }
        
        output.stopRecording()
        isRecording = false
        
        // Wait for recording to complete
        return try await withCheckedThrowingContinuation { continuation in
            // Implementation depends on delegate pattern
        }
    }
}

// Stream identifier for tracking
struct StreamIdentifier: Hashable {
    private let uuid = UUID()
}
```

## 5. Performance Optimization

### 5.1 Adaptive Quality Management

```swift
// AdaptiveQualityManager.swift
class AdaptiveQualityManager {
    private let thermalMonitor = ThermalMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let batteryMonitor = BatteryMonitor()
    
    private var currentQualityProfile: QualityProfile = .high
    private var qualityAdjustmentTimer: Timer?
    
    func startMonitoring() {
        thermalMonitor.startMonitoring()
        memoryMonitor.startMonitoring()
        batteryMonitor.startMonitoring()
        
        // Start periodic quality assessment
        qualityAdjustmentTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.assessAndAdjustQuality()
            }
        }
    }
    
    private func assessAndAdjustQuality() async {
        let thermalState = await thermalMonitor.currentThermalState
        let memoryPressure = await memoryMonitor.currentMemoryPressure
        let batteryLevel = await batteryMonitor.currentBatteryLevel
        
        let recommendedProfile = calculateOptimalQuality(
            thermal: thermalState,
            memory: memoryPressure,
            battery: batteryLevel
        )
        
        if recommendedProfile != currentQualityProfile {
            await applyQualityProfile(recommendedProfile)
        }
    }
    
    private func calculateOptimalQuality(
        thermal: ThermalState,
        memory: MemoryPressure,
        battery: Float
    ) -> QualityProfile {
        switch (thermal, memory, battery) {
        case (.critical, _, _), (_, .critical, _):
            return .low
        case (.serious, _, _), (_, .warning, _):
            return battery < 0.2 ? .low : .medium
        case (.fair, _, _):
            return battery < 0.3 ? .medium : .high
        default:
            return .veryHigh
        }
    }
    
    private func applyQualityProfile(_ profile: QualityProfile) async {
        currentQualityProfile = profile
        
        // Notify capture service of quality change
        NotificationCenter.default.post(
            name: .qualityProfileDidChange,
            object: profile
        )
    }
}

// Quality profiles
enum QualityProfile {
    case veryHigh    // 4K 60fps
    case high        // 4K 30fps
    case medium      // 1080p 60fps
    case low         // 1080p 30fps
    
    var maxResolution: CGSize {
        switch self {
        case .veryHigh, .high: return CGSize(width: 3840, height: 2160)
        case .medium, .low: return CGSize(width: 1920, height: 1080)
        }
    }
    
    var maxFrameRate: Float64 {
        switch self {
        case .veryHigh: return 60
        case .high: return 30
        case .medium: return 60
        case .low: return 30
        }
    }
}
```

## 6. Error Handling and Recovery

### 6.1 Multi-Camera Error Handling

```swift
// MultiCamErrorHandler.swift
class MultiCamErrorHandler {
    private let captureService: CaptureService
    
    init(captureService: CaptureService) {
        self.captureService = captureService
    }
    
    func handleMultiCamError(_ error: MultiCamError) async {
        switch error {
        case .sessionNotSupported:
            await fallbackToSingleCamera()
        case .deviceUnavailable:
            await attemptDeviceRecovery()
        case .insufficientResources:
            await reduceResourceUsage()
        case .thermalLimitation:
            await enableThermalProtection()
        case .configurationFailed:
            await attemptReconfiguration()
        }
    }
    
    private func fallbackToSingleCamera() async {
        // Disable multi-camera mode
        // Restart with single camera configuration
        // Notify user of fallback
    }
    
    private func attemptDeviceRecovery() async {
        // Try to rediscover devices
        // Reconfigure session with available devices
        // Graceful degradation if necessary
    }
    
    private func reduceResourceUsage() async {
        // Lower quality settings
        // Disable non-essential features
        // Close background processes
    }
    
    private func enableThermalProtection() async {
        // Reduce frame rates
        // Lower resolution
        // Disable secondary streams temporarily
    }
}

// Enhanced error types
enum MultiCamError: Error, LocalizedError {
    case sessionNotSupported
    case deviceUnavailable(AVCaptureDevice)
    case insufficientResources
    case thermalLimitation
    case configurationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotSupported:
            return "Multi-camera session is not supported on this device"
        case .deviceUnavailable(let device):
            return "Camera \(device.localizedName) is unavailable"
        case .insufficientResources:
            return "Insufficient system resources for multi-camera operation"
        case .thermalLimitation:
            return "Device temperature too high for multi-camera operation"
        case .configurationFailed(let reason):
            return "Multi-camera configuration failed: \(reason)"
        }
    }
}
```

## 7. Testing Implementation

### 7.1 Unit Tests for Multi-Camera

```swift
// MultiCamTests.swift
import XCTest
import AVFoundation
@testable import AVCam

class MultiCamTests: XCTestCase {
    var captureService: CaptureService!
    var deviceLookup: DeviceLookup!
    
    override func setUp() {
        super.setUp()
        captureService = CaptureService()
        deviceLookup = DeviceLookup()
    }
    
    func testMultiCamSessionCreation() async {
        // Test multi-camera session initialization
        XCTAssertTrue(AVCaptureMultiCamSession.isMultiCamSupported)
        
        let session = AVCaptureMultiCamSession()
        XCTAssertNotNil(session)
        XCTAssertTrue(session.isMultiCamSupported)
    }
    
    func testDeviceDiscovery() {
        // Test multi-camera device discovery
        let deviceSet = deviceLookup.getMultiCamDeviceSet()
        XCTAssertNotNil(deviceSet)
        XCTAssertGreaterThanOrEqual(deviceSet!.devices.count, 2)
    }
    
    func testFormatSelection() throws {
        // Test multi-camera format selection
        guard let deviceSet = deviceLookup.getMultiCamDeviceSet() else {
            throw XCTSkip("No multi-camera devices available")
        }
        
        let primaryDevice = deviceSet.primaryDevice
        let multiCamFormats = primaryDevice.formats.filter { $0.isMultiCamSupported }
        XCTAssertFalse(multiCamFormats.isEmpty)
    }
    
    func testQualityAdaptation() async {
        // Test adaptive quality management
        let qualityManager = AdaptiveQualityManager()
        qualityManager.startMonitoring()
        
        // Simulate thermal state change
        let profile = qualityManager.calculateOptimalQuality(
            thermal: .serious,
            memory: .normal,
            battery: 0.5
        )
        
        XCTAssertEqual(profile, .medium)
    }
}
```

## 8. Best Practices

### 8.1 Performance Best Practices

1. **Memory Management**
   - Use buffer pooling for video frames
   - Release unused resources promptly
   - Monitor memory pressure continuously

2. **Thermal Management**
   - Implement quality degradation strategies
   - Monitor device temperature regularly
   - Provide user feedback for thermal issues

3. **Power Optimization**
   - Use efficient codec selection
   - Implement background mode properly
   - Optimize for battery life

### 8.2 User Experience Best Practices

1. **Graceful Degradation**
   - Always provide fallback to single camera
   - Clear error messages and recovery options
   - Maintain app stability during failures

2. **Intuitive Controls**
   - Simple layout switching
   - Clear indication of active cameras
   - Easy access to advanced features

3. **Performance Feedback**
   - Real-time quality indicators
   - Recording status for each stream
   - Storage space warnings

## Conclusion

This implementation guide provides a comprehensive foundation for adding multi-camera functionality to AVCam. The modular approach allows for incremental development and testing, ensuring a robust and performant implementation.

Remember to test thoroughly on various devices and under different conditions to ensure the best possible user experience.