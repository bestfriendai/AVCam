/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
State machine for camera session management.
*/

import AVFoundation
import Foundation

/// Represents the current state of the camera session.
@Observable
class CameraSessionState {
    
    /// The current state of the camera session
    var current: State = .uninitialized
    
    /// Whether the session is currently transitioning between states
    var isTransitioning: Bool {
        if case .transitioning = current {
            return true
        }
        return false
    }
    
    /// Whether the session is in an error state
    var hasError: Bool {
        if case .error = current {
            return true
        }
        return false
    }
    
    /// Whether dual camera is currently active
    var isDualCameraActive: Bool {
        if case .dualCamera = current {
            return true
        }
        return false
    }
    
    /// The possible states of the camera session
    indirect enum State: Equatable {
        case uninitialized
        case singleCamera(device: CameraDevice)
        case dualCamera(primary: CameraDevice, secondary: CameraDevice)
        case transitioning(from: State, to: State, progress: String)
        case error(CameraSessionError)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.uninitialized, .uninitialized):
                return true
            case (.singleCamera(let d1), .singleCamera(let d2)):
                return d1 == d2
            case (.dualCamera(let p1, let s1), .dualCamera(let p2, let s2)):
                return p1 == p2 && s1 == s2
            case (.transitioning, .transitioning):
                return true // Simplified comparison
            case (.error(let e1), .error(let e2)):
                return e1.localizedDescription == e2.localizedDescription
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .uninitialized:
                return "Uninitialized"
            case .singleCamera(let device):
                return "Single Camera (\(device.position.description))"
            case .dualCamera(let primary, let secondary):
                return "Dual Camera (\(primary.position.description) + \(secondary.position.description))"
            case .transitioning(_, _, let progress):
                return "Transitioning: \(progress)"
            case .error(let error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Simplified camera device info for state tracking
    struct CameraDevice: Equatable {
        let position: AVCaptureDevice.Position
        let modelID: String
        let localizedName: String

        init(device: AVCaptureDevice) {
            self.position = device.position
            self.modelID = device.modelID
            self.localizedName = device.localizedName
        }

        /// Convenience initializer for creating placeholder devices
        init(position: AVCaptureDevice.Position, modelID: String, localizedName: String) {
            self.position = position
            self.modelID = modelID
            self.localizedName = localizedName
        }

        static func == (lhs: CameraDevice, rhs: CameraDevice) -> Bool {
            return lhs.position == rhs.position && lhs.modelID == rhs.modelID
        }
    }
    
    /// Transition to a new state
    func transition(to newState: State) {
        current = newState
    }
    
    /// Begin a transition with progress tracking
    func beginTransition(from: State, to: State, progress: String) {
        current = .transitioning(from: from, to: to, progress: progress)
    }
    
    /// Complete a transition
    func completeTransition(to finalState: State) {
        current = finalState
    }
    
    /// Set error state
    func setError(_ error: CameraSessionError) {
        current = .error(error)
    }
    
    /// Clear error and return to previous state if possible
    func clearError(returnTo state: State) {
        current = state
    }
}

/// Errors specific to camera session state management
enum CameraSessionError: LocalizedError {
    case multiCamNotSupported
    case multiCamConfigurationFailed
    case deviceNotAvailable(position: AVCaptureDevice.Position)
    case formatIncompatible(primary: String, secondary: String)
    case sessionConfigurationFailed(underlying: Error)
    case insufficientResources
    case thermalThrottling
    case permissionDenied
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .multiCamNotSupported:
            return "Dual Camera Not Supported"
        case .multiCamConfigurationFailed:
            return "Dual Camera Configuration Failed"
        case .deviceNotAvailable(let position):
            return "\(position == .front ? "Front" : "Rear") Camera Unavailable"
        case .formatIncompatible(let primary, let secondary):
            return "Camera Formats Incompatible (\(primary) + \(secondary))"
        case .sessionConfigurationFailed:
            return "Camera Setup Failed"
        case .insufficientResources:
            return "Insufficient Device Resources"
        case .thermalThrottling:
            return "Device Too Hot"
        case .permissionDenied:
            return "Camera Permission Denied"
        case .unknown:
            return "Unknown Camera Error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .multiCamNotSupported:
            return "This device doesn't support dual camera mode. Requires iPhone 11 or newer."
        case .multiCamConfigurationFailed:
            return "Dual camera setup failed. This may be due to thermal throttling, resource constraints, or incompatible formats. Try again after letting the device cool down."
        case .deviceNotAvailable:
            return "Check camera permissions in Settings and try again."
        case .formatIncompatible(let primary, let secondary):
            return "Cameras \(primary) and \(secondary) cannot be used simultaneously. Using single camera mode."
        case .sessionConfigurationFailed(let error):
            return "Camera configuration failed: \(error.localizedDescription). Try restarting the app."
        case .insufficientResources:
            return "Close other apps and try again. Dual camera requires significant device resources."
        case .thermalThrottling:
            return "Let your device cool down before using dual camera mode."
        case .permissionDenied:
            return "Grant camera access in Settings > Privacy > Camera."
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .multiCamNotSupported:
            return "Device hardware limitation"
        case .multiCamConfigurationFailed:
            return "Multi-camera session configuration failed"
        case .deviceNotAvailable:
            return "Camera hardware not accessible"
        case .formatIncompatible:
            return "Incompatible video formats"
        case .sessionConfigurationFailed:
            return "AVFoundation configuration error"
        case .insufficientResources:
            return "Memory or CPU constraints"
        case .thermalThrottling:
            return "Device thermal state too high"
        case .permissionDenied:
            return "User has not granted camera permission"
        case .unknown:
            return "Unexpected system error"
        }
    }
}

extension AVCaptureDevice.Position {
    var description: String {
        switch self {
        case .front:
            return "Front"
        case .back:
            return "Rear"
        case .unspecified:
            return "Unspecified"
        @unknown default:
            return "Unknown"
        }
    }
}

