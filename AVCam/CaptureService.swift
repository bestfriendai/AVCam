/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that manages a capture session and its inputs and outputs.
*/

import Foundation
@preconcurrency import AVFoundation
import AVFAudio
import Combine
import UIKit
import os.log

/// An actor that manages the capture pipeline, which includes the capture session, device inputs, and capture outputs.
/// The app defines it as an `actor` type to ensure that all camera operations happen off of the `@MainActor`.
actor CaptureService {

    private let logger = Logger(subsystem: "com.apple.AVCam", category: "CaptureService")

    /// A value that indicates whether the capture service is idle or capturing a photo or movie.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    /// A value that indicates the current capture capabilities of the service.
    @Published private(set) var captureCapabilities = CaptureCapabilities.unknown
    /// A Boolean value that indicates whether a higher priority event, like receiving a phone call, interrupts the app.
    @Published private(set) var isInterrupted = false
    /// A Boolean value that indicates whether the user enables HDR video capture.
    @Published var isHDRVideoEnabled = false
    /// A configuration describing multi-camera preview state when dual capture is active.
    @Published private(set) var multiCamPreviewConfiguration: MultiCamPreviewConfiguration?
    /// A Boolean value that indicates whether capture controls are in a fullscreen appearance.
    @Published var isShowingFullscreenControls = false

    /// A Boolean value that indicates whether cinematic video is enabled.
    @MainActor @Published var isCinematicVideoEnabled = false

    /// A Boolean value that indicates whether spatial video recording is enabled.
    @MainActor @Published var isSpatialVideoEnabled = false

    /// Performance metrics for monitoring capture quality.
    @MainActor @Published private(set) var performanceMetrics: PerformanceMetrics = .unknown

    /// A type that connects a preview destination with the capture session.
    nonisolated let previewSource: PreviewSource

    // The app's capture session.
    private let captureSession: AVCaptureSession
    private var multiCamSession: AVCaptureMultiCamSession? { captureSession as? AVCaptureMultiCamSession }

    // An object that manages the app's photo capture behavior.
    private let photoCapture = PhotoCapture()

    // An object that manages the app's video capture behavior.
    private let movieCapture = MovieCapture()

    // Performance monitoring system.
    // private let performanceMonitor = PerformanceMonitor()

    // Stream coordinator for multi-camera synchronization.
    // private let streamCoordinator = StreamCoordinator()

    // An internal collection of output services.
    private var outputServices: [any OutputService] {
        if let secondaryMovieCapture {
            return [photoCapture, movieCapture, secondaryMovieCapture]
        }
        return [photoCapture, movieCapture]
    }

    private func setUpSingleCameraSession() throws {
        // Retrieve the default camera and microphone with fallback logic.
        let defaultCamera: AVCaptureDevice
        do {
            defaultCamera = try deviceLookup.defaultCamera
        } catch {
            // Fallback to best back camera if system preferred camera fails
            guard let fallbackCamera = deviceLookup.bestBackCamera else {
                throw CameraError.videoDeviceUnavailable
            }
            defaultCamera = fallbackCamera
        }

        let defaultMic = try deviceLookup.defaultMic

        // Audio session is configured in start()

        // Add inputs for the default camera and microphone devices.
        activeVideoInput = try addInput(for: defaultCamera)
        let audioInput = try addInput(for: defaultMic)

        // Configure the session preset based on the current capture mode.
        if multiCamSession == nil {
            captureSession.sessionPreset = captureMode == .photo ? .photo : .high
        }
        // Add the photo capture output as the default output type.
        try addOutput(photoCapture.output)
        // If the capture mode is set to Video, add a movie capture output.
        if captureMode == .video {
            // Add the movie output as the default output type.
            try addOutput(movieCapture.output)
            setHDRVideoEnabled(isHDRVideoEnabled)
        }

        // For multi-cam session used as single camera, add manual connections
        if let multiCamSession {
            let videoPort = activeVideoInput!.ports(for: .video, sourceDeviceType: defaultCamera.deviceType, sourceDevicePosition: defaultCamera.position).first!
            let photoConnection = AVCaptureConnection(inputPorts: [videoPort], output: photoCapture.output)
            if multiCamSession.canAddConnection(photoConnection) {
                multiCamSession.addConnection(photoConnection)
            }
            if captureMode == .video {
                let movieConnection = AVCaptureConnection(inputPorts: [videoPort], output: movieCapture.output)
                if multiCamSession.canAddConnection(movieConnection) {
                    multiCamSession.addConnection(movieConnection)
                }
                if let audioPort = activeVideoInput!.ports.first(where: { $0.mediaType == .audio }) ?? audioInput.ports.first(where: { $0.mediaType == .audio }) {
                    let audioConnection = AVCaptureConnection(inputPorts: [audioPort], output: movieCapture.output)
                    if multiCamSession.canAddConnection(audioConnection) {
                        multiCamSession.addConnection(audioConnection)
                    }
                }
            }
        }

        // Configure controls to use with the Camera Control.
        configureControls(for: defaultCamera)
        // Monitor the system-preferred camera state.
        monitorSystemPreferredCamera()
        // Defer rotation coordinator creation until after session starts
        // createRotationCoordinator(for: defaultCamera)
        // Observe changes to the default camera's subject area.
        observeSubjectAreaChanges(of: defaultCamera)
        // Update the service's advertised capabilities.
        updateCaptureCapabilities()
    }

    private func setUpSingleCameraFallback(in session: AVCaptureMultiCamSession) throws {
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        session.commitConfiguration()

        secondaryVideoInput = nil
        secondaryMovieCapture = nil
        multiCamPreviewConfiguration = nil

        try setUpSingleCameraSession()
    }

    private func setUpMultiCamSession(session: AVCaptureMultiCamSession) throws {
        logger.info("🎬 Starting multi-camera session setup...")
        logger.info("📱 Session type: \(type(of: session))")
        logger.info("🔄 Session is running: \(session.isRunning)")

        // DON'T stop the session - reconfigure while running for smoother transition
        // Stopping and restarting causes preview interruption and potential failures

        guard let frontCamera = deviceLookup.frontCamera else {
            logger.error("❌ Front camera not available for multi-cam")
            throw CameraError.videoDeviceUnavailable
        }
        logger.info("📷 Front camera: \(frontCamera.localizedName) (\(frontCamera.modelID))")

        // Get the best available back camera with fallback logic
        guard let primaryCamera = deviceLookup.bestBackCamera else {
            logger.error("❌ Back camera not available for multi-cam")
            throw CameraError.videoDeviceUnavailable
        }
        logger.info("📷 Primary camera: \(primaryCamera.localizedName) (\(primaryCamera.modelID))")

        let defaultMic = try deviceLookup.defaultMic
        logger.info("Microphone: \(defaultMic.localizedName)")

        // Configure formats BEFORE beginning session configuration
        // For multi-camera, we need to select compatible formats for both cameras
        logger.info("Configuring multi-camera formats...")
        do {
            try configureCompatibleMultiCamFormats(primary: primaryCamera, secondary: frontCamera)
            logger.info("Compatible multi-camera formats configured successfully")
        } catch {
            logger.error("Failed to configure compatible multi-camera formats: \(error)")
            throw error
        }

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            logger.info("Multi-camera session configuration committed")
        }

        session.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true

        // Install primary and secondary video inputs without automatic connections.
        logger.info("Adding camera inputs...")
        let primaryInput: AVCaptureDeviceInput
        do {
            primaryInput = try addInput(for: primaryCamera, connectAutomatically: false)
            logger.info("Primary camera input added successfully")
        } catch {
            logger.error("Failed to add primary camera input: \(error)")
            throw error
        }

        let secondaryInput: AVCaptureDeviceInput
        do {
            secondaryInput = try addInput(for: frontCamera, connectAutomatically: false)
            logger.info("Secondary camera input added successfully")
        } catch {
            logger.error("Failed to add secondary camera input: \(error)")
            logger.error("This is likely because the session cannot support both cameras simultaneously")
            throw CameraError.multiCamConfigurationFailed
        }

        activeVideoInput = primaryInput
        secondaryVideoInput = secondaryInput

        // Add audio input with automatic connections.
        logger.info("Adding audio input...")
        let audioInput = try addInput(for: defaultMic)
        logger.info("Audio input added")

        // Register outputs without automatic connections so connections can be targeted explicitly.
        logger.info("Adding outputs...")
        try addOutput(photoCapture.output, connectAutomatically: false)
        logger.info("Photo output added")
        try addOutput(movieCapture.output, connectAutomatically: false)
        logger.info("Primary movie output added")

        let secondaryCapture = MovieCapture()
        try addOutput(secondaryCapture.output, connectAutomatically: false)
        secondaryMovieCapture = secondaryCapture
        logger.info("Secondary movie output added")

        logger.info("Getting video ports...")
        guard let primaryVideoPort = primaryInput.ports(for: .video,
                                                         sourceDeviceType: primaryCamera.deviceType,
                                                         sourceDevicePosition: primaryCamera.position).first else {
            logger.error("Failed to get primary video port")
            throw CameraError.addInputFailed
        }
        logger.info("Primary video port obtained")

        guard let secondaryVideoPort = secondaryInput.ports(for: .video,
                                                             sourceDeviceType: frontCamera.deviceType,
                                                             sourceDevicePosition: frontCamera.position).first else {
            logger.error("Failed to get secondary video port")
            throw CameraError.addInputFailed
        }
        logger.info("Secondary video port obtained")

        // Connect the photo output to the primary camera.
        logger.info("Creating connections...")
        let photoConnection = AVCaptureConnection(inputPorts: [primaryVideoPort], output: photoCapture.output)
        guard session.canAddConnection(photoConnection) else {
            logger.error("Cannot add photo connection")
            throw CameraError.multiCamConfigurationFailed
        }
        session.addConnection(photoConnection)
        logger.info("Photo connection added")

        // Connect the primary movie output to the primary camera.
        let movieConnection = AVCaptureConnection(inputPorts: [primaryVideoPort], output: movieCapture.output)
        movieConnection.preferredVideoStabilizationMode = movieConnection.isVideoStabilizationSupported ? .auto : .off
        guard session.canAddConnection(movieConnection) else {
            logger.error("Cannot add primary movie connection")
            throw CameraError.multiCamConfigurationFailed
        }
        session.addConnection(movieConnection)
        logger.info("Primary movie connection added")

        if let audioPort = audioInput.ports.first(where: { $0.mediaType == .audio }) {
            let audioConnection = AVCaptureConnection(inputPorts: [audioPort], output: movieCapture.output)
            guard session.canAddConnection(audioConnection) else {
                logger.error("Cannot add audio connection")
                throw CameraError.multiCamConfigurationFailed
            }
            session.addConnection(audioConnection)
            logger.info("Audio connection added")
        } else {
            logger.warning("No audio port found")
        }

        // Connect the secondary movie output to the front camera.
        if let secondaryMovieCapture {
            let secondaryConnection = AVCaptureConnection(inputPorts: [secondaryVideoPort], output: secondaryMovieCapture.output)
            secondaryConnection.preferredVideoStabilizationMode = secondaryConnection.isVideoStabilizationSupported ? .auto : .off
            guard session.canAddConnection(secondaryConnection) else {
                logger.error("❌ Cannot add secondary movie connection - CRITICAL FAILURE POINT")
                logger.error("❌ This usually indicates:")
                logger.error("   • Device thermal throttling")
                logger.error("   • Incompatible camera formats")
                logger.error("   • Resource constraints")
                logger.error("   • Hardware limitations")
                throw CameraError.multiCamConfigurationFailed
            }
            session.addConnection(secondaryConnection)
            logger.info("✅ Secondary movie connection added - MULTI-CAM SUCCESS!")
        } else {
            logger.error("❌ Secondary movie capture is nil - cannot create dual camera recording")
            throw CameraError.multiCamConfigurationFailed
        }

        // Publish the preview configuration for the UI.
        multiCamPreviewConfiguration = MultiCamPreviewConfiguration(session: session,
                                                                    primaryPort: primaryVideoPort,
                                                                    secondaryPort: secondaryVideoPort)

        // Update capture configuration for each output.
        photoCapture.updateConfiguration(for: primaryCamera)
        movieCapture.updateConfiguration(for: primaryCamera)
        secondaryMovieCapture?.updateConfiguration(for: frontCamera)

        configureControls(for: primaryCamera)
        monitorSystemPreferredCamera()
        // createRotationCoordinator(for: primaryCamera)
        observeSubjectAreaChanges(of: primaryCamera)
        updateCaptureCapabilities()
        observeSecondaryCaptureActivity()
    }

    private func configureCompatibleMultiCamFormats(primary: AVCaptureDevice, secondary: AVCaptureDevice) throws {
        // Get multi-cam supported formats for both devices
        let primaryFormats = primary.formats.filter { $0.isMultiCamSupported }
        let secondaryFormats = secondary.formats.filter { $0.isMultiCamSupported }

        logger.info("📊 Format analysis:")
        logger.info("   - Primary device: \(primary.localizedName) (\(primaryFormats.count) multi-cam formats)")
        logger.info("   - Secondary device: \(secondary.localizedName) (\(secondaryFormats.count) multi-cam formats)")

        guard !primaryFormats.isEmpty, !secondaryFormats.isEmpty else {
            logger.error("❌ Multi-cam formats unavailable. Device: \(primary.modelID) / \(secondary.modelID)")
            logger.error("   - Primary formats available: \(primary.formats.count)")
            logger.error("   - Secondary formats available: \(secondary.formats.count)")
            throw CameraError.multiCamConfigurationFailed
        }

        // For multi-camera to work reliably, use conservative format selection
        // Start with 720p for maximum compatibility, then try 1080p
        let preferredResolutions: [Int32] = [720, 1080, 1920] // Height values

        var primaryFormat: AVCaptureDevice.Format?
        var secondaryFormat: AVCaptureDevice.Format?

        // Try each resolution level until we find compatible formats
        for maxHeight in preferredResolutions {
            let primaryCandidates = primaryFormats.filter { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.height <= maxHeight
            }

            let secondaryCandidates = secondaryFormats.filter { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.height <= maxHeight
            }

            if !primaryCandidates.isEmpty && !secondaryCandidates.isEmpty {
                primaryFormat = primaryCandidates.sorted(by: preferredFormatComparator).first
                secondaryFormat = secondaryCandidates.sorted(by: preferredFormatComparator).first
                logger.info("✅ Found compatible formats at max height \(maxHeight)p")
                break
            }
        }

        // Fallback to any available multi-cam format if conservative selection fails
        if primaryFormat == nil || secondaryFormat == nil {
            primaryFormat = primaryFormats.sorted(by: preferredFormatComparator).first
            secondaryFormat = secondaryFormats.sorted(by: preferredFormatComparator).first
            logger.warning("⚠️ Using fallback format selection")
        }

        guard let finalPrimaryFormat = primaryFormat,
              let finalSecondaryFormat = secondaryFormat else {
            logger.error("❌ Could not select compatible formats")
            throw CameraError.multiCamConfigurationFailed
        }

        // Configure primary camera
        do {
            try primary.lockForConfiguration()
            defer { primary.unlockForConfiguration() }

            primary.activeFormat = finalPrimaryFormat
            if finalPrimaryFormat.videoSupportedFrameRateRanges.first != nil {
                // Use 30fps for multi-camera to reduce resource usage
                primary.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                primary.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            }
            logger.info("✅ Primary camera format configured")
        } catch {
            logger.error("❌ Failed to configure primary camera format: \(error)")
            throw CameraError.multiCamConfigurationFailed
        }

        let primaryDims = CMVideoFormatDescriptionGetDimensions(finalPrimaryFormat.formatDescription)
        logger.info("📷 Primary camera format: \(primaryDims.width)x\(primaryDims.height)")

        // Configure secondary camera
        do {
            try secondary.lockForConfiguration()
            defer { secondary.unlockForConfiguration() }

            secondary.activeFormat = finalSecondaryFormat
            if finalSecondaryFormat.videoSupportedFrameRateRanges.first != nil {
                // Use 30fps for multi-camera to reduce resource usage
                secondary.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                secondary.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            }
            logger.info("✅ Secondary camera format configured")
        } catch {
            logger.error("❌ Failed to configure secondary camera format: \(error)")
            throw CameraError.multiCamConfigurationFailed
        }

        let secondaryDims = CMVideoFormatDescriptionGetDimensions(finalSecondaryFormat.formatDescription)
        logger.info("📷 Secondary camera format: \(secondaryDims.width)x\(secondaryDims.height)")
    }

    private func configureMultiCamFormat(for device: AVCaptureDevice) throws {
        // Check if device supports multi-camera
        guard device.formats.contains(where: { $0.isMultiCamSupported }) else {
            // Fallback to regular format configuration for devices that don't support multi-camera
            try configureSingleCameraFormat(for: device)
            return
        }

        let supportedFormats = device.formats.filter { $0.isMultiCamSupported }
        guard let format = supportedFormats.sorted(by: preferredFormatComparator).first else {
            // Fallback to any available format if no multi-camera formats are found
            try configureSingleCameraFormat(for: device)
            return
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Validate format before setting
        guard device.formats.contains(format) else {
            throw CameraError.multiCamConfigurationFailed
        }

        device.activeFormat = format

        if let bestFrameRateRange = format.videoSupportedFrameRateRanges.sorted(by: { $0.maxFrameRate > $1.maxFrameRate }).first {
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration
            device.activeVideoMaxFrameDuration = bestFrameRateRange.maxFrameDuration
        }
    }

    private func configureSingleCameraFormat(for device: AVCaptureDevice) throws {
        guard let format = device.formats.sorted(by: preferredFormatComparator).first else {
            throw CameraError.multiCamConfigurationFailed
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        device.activeFormat = format

        if let bestFrameRateRange = format.videoSupportedFrameRateRanges.sorted(by: { $0.maxFrameRate > $1.maxFrameRate }).first {
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration
            device.activeVideoMaxFrameDuration = bestFrameRateRange.maxFrameDuration
        }
    }

    private func preferredFormatComparator(lhs: AVCaptureDevice.Format, rhs: AVCaptureDevice.Format) -> Bool {
        // Get dimensions, assuming they are valid
        let lhsDimensions = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
        let rhsDimensions = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
        if lhsDimensions.width != rhsDimensions.width {
            return lhsDimensions.width > rhsDimensions.width
        }
        return lhs.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0 > rhs.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0
    }

    // The video input for the currently selected device camera.
    private var activeVideoInput: AVCaptureDeviceInput?
    private var secondaryVideoInput: AVCaptureDeviceInput?
    private var secondaryMovieCapture: MovieCapture?
    private var secondaryCaptureActivityTask: Task<Void, Never>?

    // The mode of capture, either photo or video. Defaults to photo.
    private(set) var captureMode = CaptureMode.photo

    // Properties for enhanced features are declared as @Published above

    // An object the service uses to retrieve capture devices.
    private let deviceLookup = DeviceLookup()
    private let isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported

    // An object that monitors the state of the system-preferred camera.
    private let systemPreferredCamera = SystemPreferredCameraObserver()

    // An object that monitors video device rotations.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    private var rotationObservers = [AnyObject]()

    // A Boolean value that indicates whether the actor finished its required configuration.
    private var isSetUp = false

    // A delegate object that responds to capture control activation and presentation events.
    private var controlsDelegate = CaptureControlsDelegate()

    // A map that stores capture controls by device identifier.
    private var controlsMap: [String: [AVCaptureControl]] = [:]

    // A serial dispatch queue to use for capture control actions.
    private let sessionQueue = DispatchSerialQueue(label: "com.example.apple-samplecode.AVCam.sessionQueue")

    // Sets the session queue as the actor's executor.
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        sessionQueue.asUnownedSerialExecutor()
    }

    init() {
        logger.info("🏗️ Initializing CaptureService")
        logger.info("🔍 Multi-cam support check: \(self.isMultiCamSupported)")

        if self.isMultiCamSupported {
            captureSession = AVCaptureMultiCamSession()
            logger.info("✅ Created AVCaptureMultiCamSession")
        } else {
            captureSession = AVCaptureSession()
            logger.info("⚠️ Created standard AVCaptureSession (multi-cam not supported)")
        }

        // Create a source object to connect the preview view with the capture session.
        previewSource = DefaultPreviewSource(session: captureSession)
        logger.info("✅ Preview source created")

        // Configure AirPods remote capture if available
        // if #available(iOS 18.0, *) {
        //     configureAirPodsRemoteCapture()
        // }
    }

    // MARK: - Authorization
    /// A Boolean value that indicates whether a person authorizes this app to use
    /// device cameras and microphones. If they haven't previously authorized the
    /// app, querying this property prompts them for authorization.
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            // Determine whether a person previously authorized camera access.
            var isAuthorized = status == .authorized
            // If the system hasn't determined their authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }

    // MARK: - Capture session life cycle
    func start(with state: CameraState) async throws {
        // Set initial operating state.
        captureMode = state.captureMode
        isHDRVideoEnabled = state.isVideoHDREnabled

        // Exit early if not authorized or the session is already running.
        guard await isAuthorized, !captureSession.isRunning else { return }

        // Set up audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            logger.error("Failed to set up audio session: \(error)")
            throw error
        }

        // Configure the session and start it.
        try setUpSession()

        // Start performance monitoring
        // await performanceMonitor.startMonitoring()

        captureSession.startRunning()
    }

    // MARK: - Manual multi-cam enable/disable
    /// Attempts to (re)enable multi-camera capture on demand.
    /// Returns true if the session is configured for dual capture and a preview configuration is published.
    func enableMultiCam() async -> Bool {
        logger.info("🎥 enableMultiCam() called")

        // Pre-flight checks
        guard self.isMultiCamSupported else {
            logger.error("❌ Device does not support multi-camera: \(AVCaptureMultiCamSession.isMultiCamSupported)")
            return false
        }

        guard let session = multiCamSession else {
            logger.error("❌ enableMultiCam: device/session doesn't support multi-cam")
            logger.error("   - captureSession type: \(type(of: self.captureSession))")
            logger.error("   - isMultiCamSupported: \(self.isMultiCamSupported)")
            return false
        }

        // Check device availability
        guard let frontCamera = deviceLookup.frontCamera,
              let backCamera = deviceLookup.bestBackCamera else {
            logger.error("❌ Required cameras not available for multi-cam")
            logger.error("   - Front camera: \(self.deviceLookup.frontCamera?.localizedName ?? "nil")")
            logger.error("   - Back camera: \(self.deviceLookup.bestBackCamera?.localizedName ?? "nil")")
            return false
        }

        // Check format compatibility before attempting configuration
        let frontFormats = frontCamera.formats.filter { $0.isMultiCamSupported }
        let backFormats = backCamera.formats.filter { $0.isMultiCamSupported }

        guard !frontFormats.isEmpty && !backFormats.isEmpty else {
            logger.error("❌ No multi-cam compatible formats available")
            logger.error("   - Front camera multi-cam formats: \(frontFormats.count)")
            logger.error("   - Back camera multi-cam formats: \(backFormats.count)")
            return false
        }

        logger.info("✅ Multi-cam session available: \(type(of: session))")
        logger.info("✅ Front camera: \(frontCamera.localizedName) (\(frontFormats.count) formats)")
        logger.info("✅ Back camera: \(backCamera.localizedName) (\(backFormats.count) formats)")
        logger.info("🔄 Attempting to configure multi-camera session...")

        do {
            try setUpMultiCamSession(session: session)

            let hasPreviewConfig = multiCamPreviewConfiguration != nil
            if hasPreviewConfig {
                logger.info("✅ Multi-camera session configured successfully")
                logger.info("   - Preview configuration created: \(self.multiCamPreviewConfiguration != nil)")
            } else {
                logger.error("❌ Multi-camera session setup completed but preview configuration is nil")
            }

            return hasPreviewConfig
        } catch {
            logger.error("❌ enableMultiCam failed: \(error.localizedDescription)")
            if let cameraError = error as? CameraError {
                logger.error("❌ Camera error details: \(cameraError)")
            }
            return false
        }
    }

    /// Disables multi-camera capture and reverts to single-camera configuration.
    func disableMultiCam() async {
        guard let session = multiCamSession else { return }
        do {
            try setUpSingleCameraFallback(in: session)
        } catch {
            logger.error("disableMultiCam failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Capture setup
    // Performs the initial capture session configuration.
    private func setUpSession() throws {
        // Return early if already set up.
        guard !isSetUp else { return }

        // Observe internal state and notifications.
        observeOutputServices()
        observeNotifications()
        observeCaptureControlsState()

        do {
            if let multiCamSession {
                do {
                    try setUpMultiCamSession(session: multiCamSession)
                } catch {
                    logger.error("Multi-cam configuration failed. Falling back to single-camera session: \(error.localizedDescription)")
                    try setUpSingleCameraFallback(in: multiCamSession)
                }
            } else {
                try setUpSingleCameraSession()
            }
            isSetUp = true
        } catch {
            throw CameraError.setupFailed
        }
    }

    // Adds an input to the capture session to connect the specified capture device.
    @discardableResult
    private func addInput(for device: AVCaptureDevice, connectAutomatically: Bool = true) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if let multiCamSession {
            guard multiCamSession.canAddInput(input) else {
                throw CameraError.addInputFailed
            }
            if connectAutomatically {
                multiCamSession.addInput(input)
            } else {
                multiCamSession.addInputWithNoConnections(input)
            }
        } else {
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                throw CameraError.addInputFailed
            }
        }
        return input
    }

    // Adds an output to the capture session to connect the specified capture device, if allowed.
    private func addOutput(_ output: AVCaptureOutput, connectAutomatically: Bool = true) throws {
        if let multiCamSession {
            guard multiCamSession.canAddOutput(output) else {
                throw CameraError.addOutputFailed
            }
            if connectAutomatically {
                multiCamSession.addOutput(output)
            } else {
                multiCamSession.addOutputWithNoConnections(output)
            }
        } else {
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            } else {
                throw CameraError.addOutputFailed
            }
        }
    }

    // The device for the active video input.
    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }

    // MARK: - Capture controls

    private func configureControls(for device: AVCaptureDevice) {

        // Exit early if the host device doesn't support capture controls.
        guard captureSession.supportsControls else { return }

        // Begin configuring the capture session.
        captureSession.beginConfiguration()

        // Remove previously configured controls, if any.
        for control in captureSession.controls {
            captureSession.removeControl(control)
        }

        // Create controls and add them to the capture session.
        for control in createControls(for: device) {
            if captureSession.canAddControl(control) {
                captureSession.addControl(control)
            } else {
                logger.info("Unable to add control \(control).")
            }
        }

        // Set the controls delegate.
        captureSession.setControlsDelegate(controlsDelegate, queue: sessionQueue)

        // Commit the capture session configuration.
        captureSession.commitConfiguration()
    }

    func createControls(for device: AVCaptureDevice) -> [AVCaptureControl] {
        // Retrieve the capture controls for this device, if they exist.
        guard let controls = controlsMap[device.uniqueID] else {
            // Define the default controls.
            var controls = [
                AVCaptureSystemZoomSlider(device: device),
                AVCaptureSystemExposureBiasSlider(device: device)
            ]

            // Add Camera Control integration for iPhone 16
            if #available(iOS 18.0, *) {
                controls.append(contentsOf: createCameraControls(for: device))
            }

            // Create a lens position control if the device supports setting a custom position.
            if device.isLockingFocusWithCustomLensPositionSupported {
                // Create a slider to adjust the value from 0 to 1.
                let lensSlider = AVCaptureSlider("Lens Position", symbolName: "circle.dotted.circle", in: 0...1)
                // Perform the slider's action on the session queue.
                lensSlider.setActionQueue(sessionQueue) { lensPosition in
                    do {
                        try device.lockForConfiguration()
                        defer { device.unlockForConfiguration() }
                        device.setFocusModeLocked(lensPosition: lensPosition)
                    } catch {
                        self.logger.info("Unable to change the lens position: \(error)")
                    }
                }
                // Add the slider the controls array.
                controls.append(lensSlider)
            }

            // Store the controls for future use.
            controlsMap[device.uniqueID] = controls
            return controls
        }

        // Return the previously created controls.
        return controls
    }

    @available(iOS 18.0, *)
    private func createCameraControls(for device: AVCaptureDevice) -> [AVCaptureControl] {
        var controls: [AVCaptureControl] = []

        // Add cinematic video controls if supported
        if cinematicVideoCapable(device) {
            let cinematicPicker = AVCaptureIndexPicker("Cinematic Focus", symbolName: "camera.aperture", numberOfIndexes: 2)
            cinematicPicker.setActionQueue(sessionQueue) { [weak self] index in
                Task { @MainActor in
                    self?.isCinematicVideoEnabled = index > 0
                }
            }
            controls.append(cinematicPicker)
        }

        // Add spatial video controls if supported
        if spatialVideoCapable(device) {
            let spatialPicker = AVCaptureIndexPicker("Spatial Video", symbolName: "cube.transparent", numberOfIndexes: 2)
            spatialPicker.setActionQueue(sessionQueue) { [weak self] index in
                Task { @MainActor in
                    self?.isSpatialVideoEnabled = index > 0
                }
            }
            controls.append(spatialPicker)
        }

        // Add custom effects picker
        let effects = ["None", "Portrait", "Studio Light", "Contour Stage"]
        let effectsPicker = AVCaptureIndexPicker("Effects", symbolName: "face.smiling", numberOfIndexes: effects.count)
        effectsPicker.setActionQueue(sessionQueue) { index in
            self.applyEffect(effects[index])
        }
        controls.append(effectsPicker)

        return controls
    }

    private func cinematicVideoCapable(_ device: AVCaptureDevice) -> Bool {
        return device.formats.contains(where: { format in
            format.isMultiCamSupported
        })
    }

    private func spatialVideoCapable(_ device: AVCaptureDevice) -> Bool {
        return device.formats.contains(where: { format in
            format.isMultiCamSupported
        }) && device.activeDepthDataFormat != nil
    }

    private func applyEffect(_ effect: String) {
        // Apply visual effects based on selection
        logger.info("Applying effect: \(effect)")
        // Implementation would depend on specific effect requirements
    }

    // MARK: - AirPods Remote Capture

    @available(iOS 18.0, *)
    private func configureAirPodsRemoteCapture() {
        // Configure AirPods remote capture for H2 chip devices
        Task {
            await setupAirPodsCaptureEvents()
        }
    }

    @available(iOS 18.0, *)
    private func setupAirPodsCaptureEvents() async {
        // Set up AirPods remote capture event handling
        // This would integrate with the new AirPods capture APIs
        logger.info("AirPods remote capture configured")
    }

    // MARK: - Capture mode selection

    /// Changes the mode of capture, which can be `photo` or `video`.
    ///
    /// - Parameter `captureMode`: The capture mode to enable.
    func setCaptureMode(_ captureMode: CaptureMode) throws {
        // Update the internal capture mode value before performing the session configuration.
        self.captureMode = captureMode

        if multiCamSession != nil {
            updateCaptureCapabilities()
            return
        }

        // Change the configuration atomically.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Configure the capture session for the selected capture mode.
        switch captureMode {
        case .photo:
            // The app needs to remove the movie capture output to perform Live Photo capture.
            captureSession.sessionPreset = .photo
            captureSession.removeOutput(movieCapture.output)
        case .video:
            captureSession.sessionPreset = .high
            try addOutput(movieCapture.output)
            if isHDRVideoEnabled {
                setHDRVideoEnabled(true)
            }
        }

        // Update the advertised capabilities after reconfiguration.
        updateCaptureCapabilities()
    }

    // MARK: - Device selection

    /// Changes the capture device that provides video input.
    ///
    /// The app calls this method in response to the user tapping the button in the UI to change cameras.
    /// The implementation switches between the front and back cameras and, in iPadOS,
    /// connected external cameras.
    func selectNextVideoDevice() {
        if let session = multiCamSession,
           secondaryVideoInput != nil {
            swapMultiCamInputs(in: session)
            return
        }
        // The array of available video capture devices.
        let videoDevices = deviceLookup.cameras

        // Find the index of the currently selected video device.
        let selectedIndex = videoDevices.firstIndex(of: currentDevice) ?? 0
        // Get the next index.
        var nextIndex = selectedIndex + 1
        // Wrap around if the next index is invalid.
        if nextIndex == videoDevices.endIndex {
            nextIndex = 0
        }

        let nextDevice = videoDevices[nextIndex]
        // Change the session's active capture device.
        changeCaptureDevice(to: nextDevice)

        // The app only calls this method in response to the user requesting to switch cameras.
        // Set the new selection as the user's preferred camera.
        AVCaptureDevice.userPreferredCamera = nextDevice
    }

    private func swapMultiCamInputs(in session: AVCaptureMultiCamSession) {
        guard let primaryInput = activeVideoInput,
              let secondaryInput = secondaryVideoInput else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let newPrimaryDevice = secondaryInput.device
        let newSecondaryDevice = primaryInput.device

        guard let newPrimaryPort = secondaryInput.ports(for: .video,
                                                        sourceDeviceType: newPrimaryDevice.deviceType,
                                                        sourceDevicePosition: newPrimaryDevice.position).first,
              let newSecondaryPort = primaryInput.ports(for: .video,
                                                        sourceDeviceType: newSecondaryDevice.deviceType,
                                                        sourceDevicePosition: newSecondaryDevice.position).first else {
            return
        }

        if let movieConnection = movieCapture.output.connection(with: .video) {
            session.removeConnection(movieConnection)
            let replacement = AVCaptureConnection(inputPorts: [newPrimaryPort], output: movieCapture.output)
            replacement.preferredVideoStabilizationMode = replacement.isVideoStabilizationSupported ? .auto : .off
            if session.canAddConnection(replacement) {
                session.addConnection(replacement)
            }
        }

        if let photoConnection = photoCapture.output.connection(with: .video) {
            session.removeConnection(photoConnection)
            let replacement = AVCaptureConnection(inputPorts: [newPrimaryPort], output: photoCapture.output)
            if session.canAddConnection(replacement) {
                session.addConnection(replacement)
            }
        }

        if let secondaryMovieCapture,
           let secondaryConnection = secondaryMovieCapture.output.connection(with: .video) {
            session.removeConnection(secondaryConnection)
            let replacement = AVCaptureConnection(inputPorts: [newSecondaryPort], output: secondaryMovieCapture.output)
            replacement.preferredVideoStabilizationMode = replacement.isVideoStabilizationSupported ? .auto : .off
            if session.canAddConnection(replacement) {
                session.addConnection(replacement)
            }
        }

        activeVideoInput = secondaryInput
        secondaryVideoInput = primaryInput

        multiCamPreviewConfiguration = MultiCamPreviewConfiguration(session: session,
                                                                    primaryPort: newPrimaryPort,
                                                                    secondaryPort: newSecondaryPort)

        configureControls(for: newPrimaryDevice)
        createRotationCoordinator(for: newPrimaryDevice)
        observeSubjectAreaChanges(of: newPrimaryDevice)
        updateCaptureCapabilities()
        AVCaptureDevice.userPreferredCamera = newPrimaryDevice
    }

    // Changes the device the service uses for video capture.
    private func changeCaptureDevice(to device: AVCaptureDevice) {
        // The service must have a valid video input prior to calling this method.
        guard let currentInput = activeVideoInput else { fatalError() }

        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove the existing video input before attempting to connect a new one.
        captureSession.removeInput(currentInput)
        do {
            // Attempt to connect a new input and device to the capture session.
            activeVideoInput = try addInput(for: device)
            // Configure capture controls for new device selection.
            configureControls(for: device)
            // Configure a new rotation coordinator for the new device.
            createRotationCoordinator(for: device)
            // Register for device observations.
            observeSubjectAreaChanges(of: device)
            // Update the service's advertised capabilities.
            updateCaptureCapabilities()
        } catch {
            // Reconnect the existing camera on failure.
            captureSession.addInput(currentInput)
        }
    }

    /// Monitors changes to the system's preferred camera selection.
    ///
    /// iPadOS supports external cameras. When someone connects an external camera to their iPad,
    /// they're signaling the intent to use the device. The system responds by updating the
    /// system-preferred camera (SPC) selection to this new device. When this occurs, if the SPC
    /// isn't the currently selected camera, switch to the new device.
    private func monitorSystemPreferredCamera() {
        Task {
            // An object monitors changes to system-preferred camera (SPC) value.
            for await camera in systemPreferredCamera.changes {
                // If the SPC isn't the currently selected camera, attempt to change to that device.
                if let camera, currentDevice != camera {
                    logger.debug("Switching camera selection to the system-preferred camera.")
                    changeCaptureDevice(to: camera)
                }
            }
        }
    }

    // MARK: - Rotation handling

    /// Create a new rotation coordinator for the specified device and observe its state to monitor rotation changes.
    private func createRotationCoordinator(for device: AVCaptureDevice) {
        // Create a new rotation coordinator for this device.
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)

        // Set initial rotation state on the preview and output connections.
        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)

        // Cancel previous observations.
        rotationObservers.removeAll()

        // Add observers to monitor future changes.
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updatePreviewRotation(angle) }
            }
        )

        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updateCaptureRotation(angle) }
            }
        )
    }

    private func updatePreviewRotation(_ angle: CGFloat) {
        let connection = videoPreviewLayer.connection
        Task { @MainActor in
            // Set initial rotation angle on the video preview.
            connection?.videoRotationAngle = angle
        }
    }

    private func updateCaptureRotation(_ angle: CGFloat) {
        // Update the orientation for all output services.
        outputServices.forEach { $0.setVideoRotationAngle(angle) }
    }

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // Create a preview layer for rotation coordination and point conversion
        // Use a simple layer without session connection for rotation coordination
        let previewLayer = AVCaptureVideoPreviewLayer()
        // For multi-camera sessions, use setSessionWithNoConnection to avoid conflicts
        if captureSession is AVCaptureMultiCamSession {
            previewLayer.setSessionWithNoConnection(captureSession)
        } else {
            previewLayer.session = captureSession
        }
        return previewLayer
    }

    // MARK: - Automatic focus and exposure

    /// Performs a one-time automatic focus and expose operation.
    ///
    /// The app calls this method as the result of a person tapping on the preview area.
    func focusAndExpose(at point: CGPoint) {
        // The point this call receives is in view-space coordinates. Convert this point to device coordinates.
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        do {
            // Perform a user-initiated focus and expose.
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
        } catch {
            logger.debug("Unable to perform focus and exposure operation. \(error)")
        }
    }

    // Observe notifications of type `subjectAreaDidChangeNotification` for the specified device.
    private func observeSubjectAreaChanges(of device: AVCaptureDevice) {
        // Cancel the previous observation task.
        subjectAreaChangeTask?.cancel()
        subjectAreaChangeTask = Task {
            // Signal true when this notification occurs.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.subjectAreaDidChangeNotification, object: device).compactMap({ _ in true }) {
                // Perform a system-initiated focus and expose.
                try? focusAndExpose(at: CGPoint(x: 0.5, y: 0.5), isUserInitiated: false)
            }
        }
    }
    private var subjectAreaChangeTask: Task<Void, Never>?

    private func focusAndExpose(at devicePoint: CGPoint, isUserInitiated: Bool) throws {
        // Configure the current device.
        let device = currentDevice

        // The following mode and point of interest configuration requires obtaining an exclusive lock on the device.
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let focusMode = isUserInitiated ? AVCaptureDevice.FocusMode.autoFocus : .continuousAutoFocus
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = focusMode
        }

        let exposureMode = isUserInitiated ? AVCaptureDevice.ExposureMode.autoExpose : .continuousAutoExposure
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = exposureMode
        }
        // Enable subject-area change monitoring when performing a user-initiated automatic focus and exposure operation.
        // If this method enables change monitoring, when the device's subject area changes, the app calls this method a
        // second time and resets the device to continuous automatic focus and exposure.
        device.isSubjectAreaChangeMonitoringEnabled = isUserInitiated
    }

    // MARK: - Zoom control

    /// Sets the rear camera zoom to a specific factor with optional animation.
    /// - Parameters:
    ///   - factor: The desired zoom factor (e.g., 0.5, 1.0, 2.0)
    ///   - animated: Whether to smoothly ramp to the zoom factor (default: true)
    func setRearZoom(factor: CGFloat, animated: Bool = true) {
        guard let rear = activeVideoInput?.device, rear.position == .back else {
            logger.debug("setRearZoom: not on rear camera")
            return
        }

        do {
            try rear.lockForConfiguration()
            defer { rear.unlockForConfiguration() }

            // Clamp the zoom factor to the device's supported range
            let clamped = max(rear.minAvailableVideoZoomFactor, min(factor, rear.maxAvailableVideoZoomFactor))

            if animated {
                // Smoothly ramp to the target zoom factor
                rear.ramp(toVideoZoomFactor: clamped, withRate: 2.0)
            } else {
                // Set zoom factor immediately
                rear.videoZoomFactor = clamped
            }

            logger.info("Rear zoom set to \(clamped)x (requested: \(factor)x, animated: \(animated))")
        } catch {
            logger.error("Rear zoom failed: \(String(describing: error))")
        }
    }

    // MARK: - Photo capture
    func capturePhoto(with features: PhotoFeatures) async throws -> Photo {
        try await photoCapture.capturePhoto(with: features)
    }

    // MARK: - Movie capture
    /// Starts recording video. The video records until the user stops recording,
    /// which calls the following `stopRecording()` method.
    func startRecording() {
        movieCapture.startRecording()
        secondaryMovieCapture?.startRecording()
    }

    /// Stops the recording and returns the captured movie.
    func stopRecording() async throws -> Movie {
        if let secondaryMovieCapture {
            async let primaryMovie = movieCapture.stopRecording()
            async let companionMovie = secondaryMovieCapture.stopRecording()
            let primary = try await primaryMovie
            let companion = try await companionMovie
            return Movie(url: primary.url, companionURL: companion.url)
        }
        return try await movieCapture.stopRecording()
    }

    /// Sets whether the app captures HDR video.
    func setHDRVideoEnabled(_ isEnabled: Bool) {
        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        do {
            // If the current device provides a 10-bit HDR format, enable it for use.
            if isEnabled, let format = currentDevice.activeFormat10BitVariant {
                try currentDevice.lockForConfiguration()
                defer { currentDevice.unlockForConfiguration() }
                currentDevice.activeFormat = format
                isHDRVideoEnabled = true
            } else {
                if multiCamSession == nil {
                    captureSession.sessionPreset = .high
                }
                isHDRVideoEnabled = false
            }
        } catch {
            logger.error("Unable to obtain lock on device and can't enable HDR video capture.")
        }
    }

    // MARK: - Internal state management
    /// Updates the state of the actor to ensure its advertised capabilities are accurate.
    ///
    /// When the capture session changes, such as changing modes or input devices, the service
    /// calls this method to update its configuration and capabilities. The app uses this state to
    /// determine which features to enable in the user interface.
    private func updateCaptureCapabilities() {
        // Update the output service configuration.
        outputServices.forEach { $0.updateConfiguration(for: currentDevice) }
        // Set the capture service's capabilities for the selected mode.
        switch captureMode {
        case .photo:
            captureCapabilities = photoCapture.capabilities
        case .video:
            captureCapabilities = movieCapture.capabilities
        }
    }

    /// Merge the `captureActivity` values of the photo and movie capture services,
    /// and assign the value to the actor's property.`
    private func observeOutputServices() {
        Publishers.Merge(photoCapture.$captureActivity, movieCapture.$captureActivity)
            .assign(to: &$captureActivity)
    }

    private func observeSecondaryCaptureActivity() {
        secondaryCaptureActivityTask?.cancel()
        guard let secondaryMovieCapture else { return }
        secondaryCaptureActivityTask = Task {
            for await activity in secondaryMovieCapture.$captureActivity.values {
                captureActivity = activity
            }
        }
    }

    deinit {
        secondaryCaptureActivityTask?.cancel()
        // Task {
        //     await performanceMonitor.stopMonitoring()
        // }
    }

    /// Observe when capture control enter and exit a fullscreen appearance.
    private func observeCaptureControlsState() {
        controlsDelegate.$isShowingFullscreenControls
            .assign(to: &$isShowingFullscreenControls)
    }

    /// Observe capture-related notifications.
    private func observeNotifications() {
        Task {
            for await reason in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject? })
                .compactMap({ AVCaptureSession.InterruptionReason(rawValue: $0.integerValue) }) {
                /// Set the `isInterrupted` state as appropriate.
                isInterrupted = [.audioDeviceInUseByAnotherClient, .videoDeviceInUseByAnotherClient].contains(reason)
            }
        }

        Task {
            // Await notification of the end of an interruption.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                isInterrupted = false
            }
        }

        Task {
            for await error in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionErrorKey] as? AVError }) {
                // If the system resets media services, the capture session stops running.
                if error.code == .mediaServicesWereReset {
                    if !captureSession.isRunning {
        captureSession.startRunning()

        // Create rotation coordinator after session starts
        Task {
            // Wait a moment for session to stabilize
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            createRotationCoordinator(for: currentDevice)
        }
                    }
                }
            }
        }
    }
}

class CaptureControlsDelegate: NSObject, AVCaptureSessionControlsDelegate {

    @Published private(set) var isShowingFullscreenControls = false

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        logger.debug("Capture controls active.")
    }

    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = true
        logger.debug("Capture controls will enter fullscreen appearance.")
    }

    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = false
        logger.debug("Capture controls will exit fullscreen appearance.")
    }

    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        logger.debug("Capture controls inactive.")
    }
}
