/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Comprehensive error handling and recovery system for capture operations.
*/

import Foundation
import AVFoundation
import os.log

/// A comprehensive error handling system for camera capture operations.
actor ErrorHandlingSystem {
    
    private let logger = Logger(subsystem: "com.apple.AVCam", category: "ErrorHandling")
    
    @Published private(set) var currentError: CameraError?
    @Published private(set) var recoverySuggestions: [String] = []
    @Published private(set) var isRecovering = false
    
    private var retryCount = 0
    private let maxRetries = 3
    
    /// Handles a camera error and attempts recovery if possible.
    func handleError(_ error: CameraError) async {
        currentError = error
        recoverySuggestions = generateRecoverySuggestions(for: error)
        
        if canAttemptRecovery(for: error) && retryCount < maxRetries {
            isRecovering = true
            await attemptRecovery(for: error)
            isRecovering = false
        }
    }
    
    /// Clears the current error state.
    func clearError() {
        currentError = nil
        recoverySuggestions = []
        retryCount = 0
    }
    
    private func canAttemptRecovery(for error: CameraError) -> Bool {
        switch error {
        case .videoDeviceUnavailable, .audioDeviceUnavailable, .setupFailed:
            return true
        case .addInputFailed, .addOutputFailed:
            return true
        case .deviceChangeFailed, .multiCamConfigurationFailed:
            return true
        case .cinematicVideoNotSupported, .spatialVideoNotSupported:
            return false // Feature not supported, no recovery possible
        case .insufficientResources, .thermalThrottling:
            return true
        case .externalCameraConnectionFailed:
            return true
        }
    }
    
    private func generateRecoverySuggestions(for error: CameraError) -> [String] {
        switch error {
        case .videoDeviceUnavailable:
            return [
                "Check if another app is using the camera",
                "Restart the app",
                "Restart the device if the issue persists"
            ]
        case .audioDeviceUnavailable:
            return [
                "Check if another app is using the microphone",
                "Ensure microphone permissions are granted",
                "Try using a different audio device"
            ]
        case .addInputFailed, .addOutputFailed:
            return [
                "Try switching to a different camera",
                "Restart the capture session",
                "Check device compatibility"
            ]
        case .setupFailed:
            return [
                "Restart the app",
                "Check camera permissions",
                "Ensure the device supports the requested features"
            ]
        case .deviceChangeFailed:
            return [
                "Try selecting the camera again",
                "Restart the capture session",
                "Use the default camera"
            ]
        case .multiCamConfigurationFailed:
            return [
                "Fall back to single camera mode",
                "Try a different camera combination",
                "Check if all cameras support multi-cam"
            ]
        case .cinematicVideoNotSupported:
            return [
                "Use a device that supports cinematic video",
                "Try regular video recording instead",
                "Check device compatibility in settings"
            ]
        case .spatialVideoNotSupported:
            return [
                "Use a device that supports spatial video",
                "Try regular video recording instead",
                "Enable depth data in settings"
            ]
        case .insufficientResources:
            return [
                "Close other apps to free up memory",
                "Lower video quality settings",
                "Restart the device"
            ]
        case .thermalThrottling:
            return [
                "Let the device cool down",
                "Lower video quality settings",
                "Stop other intensive processes"
            ]
        case .externalCameraConnectionFailed:
            return [
                "Check camera connection",
                "Ensure camera is properly powered",
                "Try a different cable or port"
            ]
        }
    }
    
    private func attemptRecovery(for error: CameraError) async {
        retryCount += 1
        
        // Wait a brief moment before retrying
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        switch error {
        case .videoDeviceUnavailable, .audioDeviceUnavailable:
            await retryDeviceDiscovery()
        case .addInputFailed, .addOutputFailed:
            await retrySessionConfiguration()
        case .setupFailed:
            await retrySessionSetup()
        case .deviceChangeFailed:
            await retryDeviceChange()
        case .multiCamConfigurationFailed:
            await fallbackToSingleCamera()
        case .insufficientResources:
            await reduceResourceUsage()
        case .thermalThrottling:
            await waitForThermalRecovery()
        case .externalCameraConnectionFailed:
            await retryExternalCameraConnection()
        default:
            break
        }
    }
    
    private func retryDeviceDiscovery() async {
        // Implementation would retry device discovery
        logger.info("Retrying device discovery...")
    }
    
    private func retrySessionConfiguration() async {
        // Implementation would retry session configuration
        logger.info("Retrying session configuration...")
    }
    
    private func retrySessionSetup() async {
        // Implementation would retry session setup
        logger.info("Retrying session setup...")
    }
    
    private func retryDeviceChange() async {
        // Implementation would retry device change
        logger.info("Retrying device change...")
    }
    
    private func fallbackToSingleCamera() async {
        // Implementation would fall back to single camera mode
        logger.info("Falling back to single camera mode...")
    }
    
    private func reduceResourceUsage() async {
        // Implementation would reduce resource usage
        logger.info("Reducing resource usage...")
    }
    
    private func waitForThermalRecovery() async {
        // Wait for thermal state to improve
        for _ in 0..<10 { // Check for 10 seconds
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let thermalState = ProcessInfo.processInfo.thermalState
            if thermalState == .nominal {
                logger.info("Thermal state recovered")
                return
            }
        }
        logger.warning("Thermal recovery timeout")
    }
    
    private func retryExternalCameraConnection() async {
        // Implementation would retry external camera connection
        logger.info("Retrying external camera connection...")
    }
}

/// Extension to add error handling integration to CaptureService
extension CaptureService {
    
    private let errorHandlingSystem = ErrorHandlingSystem()
    
    /// Handles errors that occur during capture operations.
    func handleCaptureError(_ error: CameraError) async {
        await errorHandlingSystem.handleError(error)
    }
    
    /// Gets the current error state.
    var currentError: CameraError? {
        get async {
            await errorHandlingSystem.currentError
        }
    }
    
    /// Gets recovery suggestions for the current error.
    var recoverySuggestions: [String] {
        get async {
            await errorHandlingSystem.recoverySuggestions
        }
    }
    
    /// Checks if the system is currently recovering from an error.
    var isRecovering: Bool {
        get async {
            await errorHandlingSystem.isRecovering
        }
    }
    
    /// Clears the current error state.
    func clearError() async {
        await errorHandlingSystem.clearError()
    }
}