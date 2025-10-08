/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that manages a movie capture output to record videos.
*/

import AVFoundation
import Combine
import VideoToolbox

/// An object that manages a movie capture output to record videos.
final class MovieCapture: OutputService {
    
    /// A value that indicates the current state of movie capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service.
    let output = AVCaptureMovieFileOutput()
    // An internal alias for the output.
    private var movieOutput: AVCaptureMovieFileOutput { output }
    
    /// Cinematic video configuration.
    private var cinematicConfiguration: CinematicVideoConfiguration = .default
    
    /// Spatial video configuration.
    private var spatialConfiguration: SpatialVideoConfiguration = .default
    
    // A delegate object to respond to movie capture events.
    private var delegate: MovieCaptureDelegate?
    
    // The interval at which to update the recording time.
    private let refreshInterval = TimeInterval(0.25)
    private var timerCancellable: AnyCancellable?
    
    // A Boolean value that indicates whether the currently selected camera's
    // active format supports HDR.
    private var isHDRSupported = false
    
    // A Boolean value that indicates whether cinematic video is supported.
    private var isCinematicVideoSupported = false
    
    // A Boolean value that indicates whether spatial video is supported.
    private var isSpatialVideoSupported = false
    
    // MARK: - Capturing a movie
    
    /// Starts movie recording.
    func startRecording() {
        // Return early if already recording.
        guard !movieOutput.isRecording else { return }
        
        guard let connection = movieOutput.connection(with: .video) else {
            fatalError("Configuration error. No video connection found.")
        }

        // Configure connection based on video mode
        configureOutputSettings(for: connection)
        
        // Enable video stabilization if the connection supports it.
        if connection.isVideoStabilizationSupported {
            if #available(iOS 18.0, *) {
                connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced
            } else {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        // Start a timer to update the recording time.
        startMonitoringDuration()
        
        delegate = MovieCaptureDelegate()
        movieOutput.startRecording(to: URL.movieFileURL, recordingDelegate: delegate!)
    }
    
    private func configureOutputSettings(for connection: AVCaptureConnection) {
        var outputSettings: [String: Any] = [:]
        
        // Configure for HEVC capture
        if movieOutput.availableVideoCodecTypes.contains(.hevc) {
            outputSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
        }
        
        // Configure cinematic video settings
        if cinematicConfiguration.isEnabled && isCinematicVideoSupported {
            if #available(iOS 18.0, *) {
                outputSettings[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
                // Configure cinematic video specific settings
                configureCinematicVideoSettings(&outputSettings)
            }
        }
        
        // Configure spatial video settings
        if spatialConfiguration.isEnabled && isSpatialVideoSupported {
            configureSpatialVideoSettings(&outputSettings)
        }
        
        if !outputSettings.isEmpty {
            movieOutput.setOutputSettings(outputSettings, for: connection)
        }
    }
    
    @available(iOS 18.0, *)
    private func configureCinematicVideoSettings(_ settings: inout [String: Any]) {
        // Configure cinematic video specific settings
        settings[AVVideoAllowFrameReorderingKey] = true
        settings[AVVideoExpectedSourceFrameRateKey] = 30
        settings[AVVideoAverageBitRateKey] = 10_000_000 // 10 Mbps for cinematic
    }
    
    private func configureSpatialVideoSettings(_ settings: inout [String: Any]) {
        // Configure spatial video specific settings
        settings[AVVideoAllowFrameReorderingKey] = true
        settings[AVVideoExpectedSourceFrameRateKey] = 60
        settings[AVVideoAverageBitRateKey] = 15_000_000 // 15 Mbps for spatial
    }
    
    /// Stops movie recording.
    /// - Returns: A `Movie` object that represents the captured movie.
    func stopRecording() async throws -> Movie {
        // Use a continuation to adapt the delegate-based capture API to an async interface.
        return try await withCheckedThrowingContinuation { continuation in
            // Set the continuation on the delegate to handle the capture result.
            delegate?.continuation = continuation
            
            /// Stops recording, which causes the output to call the `MovieCaptureDelegate` object.
            movieOutput.stopRecording()
            stopMonitoringDuration()
        }
    }
    
    // MARK: - Movie capture delegate
    /// A delegate object that responds to the capture output finalizing movie recording.
    private class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        
        var continuation: CheckedContinuation<Movie, Error>?
        
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error {
                // If an error occurs, throw it to the caller.
                continuation?.resume(throwing: error)
            } else {
                // Return a new movie object.
                continuation?.resume(returning: Movie(url: outputFileURL))
            }
        }
    }
    
    // MARK: - Monitoring recorded duration
    
    // Starts a timer to update the recording time.
    private func startMonitoringDuration() {
        captureActivity = .movieCapture()
        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Poll the movie output for its recorded duration.
                let duration = movieOutput.recordedDuration.seconds
                captureActivity = .movieCapture(duration: duration)
            }
    }
    
    /// Stops the timer and resets the time to `CMTime.zero`.
    private func stopMonitoringDuration() {
        timerCancellable?.cancel()
        captureActivity = .idle
    }
    
    func updateConfiguration(for device: AVCaptureDevice) {
        // The app supports HDR video capture if the active format supports it.
        isHDRSupported = device.activeFormat10BitVariant != nil
        
        // Check for cinematic video support
        isCinematicVideoSupported = device.formats.contains(where: { format in
            format.isMultiCamSupported
        })
        
        // Check for spatial video support
        isSpatialVideoSupported = device.formats.contains(where: { format in
            format.isMultiCamSupported
        }) && device.activeDepthDataFormat != nil
    }
    
    // MARK: - Cinematic Video Configuration
    
    /// Sets the cinematic video configuration.
    func setCinematicVideoConfiguration(_ config: CinematicVideoConfiguration) {
        cinematicConfiguration = config
    }
    
    /// Gets the current cinematic video configuration.
    func getCinematicVideoConfiguration() -> CinematicVideoConfiguration {
        return cinematicConfiguration
    }
    
    // MARK: - Spatial Video Configuration
    
    /// Sets the spatial video configuration.
    func setSpatialVideoConfiguration(_ config: SpatialVideoConfiguration) {
        spatialConfiguration = config
    }
    
    /// Gets the current spatial video configuration.
    func getSpatialVideoConfiguration() -> SpatialVideoConfiguration {
        return spatialConfiguration
    }

    // MARK: - Configuration
    /// Returns the capabilities for this capture service.
    var capabilities: CaptureCapabilities {
        CaptureCapabilities(
            isLivePhotoCaptureSupported: false,
            isHDRSupported: isHDRSupported
        )
    }
}
