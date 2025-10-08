/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that retrieves camera and microphone devices.
*/

import AVFoundation
import Combine
import os.log

/// An object that retrieves camera and microphone devices.
final class DeviceLookup {
    
    private let logger = Logger(subsystem: "com.apple.AVCam", category: "DeviceLookup")
    
    // Discovery sessions to find the front and back cameras, and external cameras in iPadOS.
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let externalCameraDiscoverSession: AVCaptureDevice.DiscoverySession
    private let ultraWideCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let telephotoCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let tripleCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    
    init() {
        backCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                                                                      mediaType: .video,
                                                                      position: .back)
        frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
                                                                       mediaType: .video,
                                                                       position: .front)
        externalCameraDiscoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
                                                                         mediaType: .video,
                                                                         position: .unspecified)
        
        // Enhanced discovery sessions for newer camera systems
        ultraWideCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera],
                                                                           mediaType: .video,
                                                                           position: .back)
        telephotoCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera],
                                                                           mediaType: .video,
                                                                           position: .back)
        tripleCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera],
                                                                        mediaType: .video,
                                                                        position: .back)
        
        // If the host doesn't currently define a system-preferred camera device, set the user's preferred selection to the back camera.
        if AVCaptureDevice.systemPreferredCamera == nil {
            AVCaptureDevice.userPreferredCamera = backCameraDiscoverySession.devices.first
        }
    }

    /// Returns the default back-facing camera if available.
    var backCamera: AVCaptureDevice? {
        backCameraDiscoverySession.devices.first
    }
    
    /// Returns triple camera if available (iPhone 13 Pro and later).
    var tripleCamera: AVCaptureDevice? {
        tripleCameraDiscoverySession.devices.first
    }
    
    /// Returns ultra-wide camera if available.
    var ultraWideCamera: AVCaptureDevice? {
        ultraWideCameraDiscoverySession.devices.first
    }
    
    /// Returns telephoto camera if available.
    var telephotoCamera: AVCaptureDevice? {
        telephotoCameraDiscoverySession.devices.first
    }
    
    /// Returns the best available back camera with fallback logic.
    var bestBackCamera: AVCaptureDevice? {
        // Try triple camera first (best quality)
        if let triple = tripleCamera {
            return triple
        }
        // Then try regular back camera
        if let back = backCamera {
            return back
        }
        // Then try ultra-wide
        if let ultraWide = ultraWideCamera {
            return ultraWide
        }
        // Finally try telephoto
        return telephotoCamera
    }

    /// Returns the default front-facing camera if available.
    var frontCamera: AVCaptureDevice? {
        frontCameraDiscoverySession.devices.first
    }

    /// Returns the system-preferred camera for the host system.
    var defaultCamera: AVCaptureDevice {
        get throws {
            guard let videoDevice = AVCaptureDevice.systemPreferredCamera else {
                throw CameraError.videoDeviceUnavailable
            }
            return videoDevice
        }
    }
    
    /// Returns the default microphone for the device on which the app runs.
    var defaultMic: AVCaptureDevice {
        get throws {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                throw CameraError.audioDeviceUnavailable
            }
            return audioDevice
        }
    }
    
    var cameras: [AVCaptureDevice] {
        // Populate the cameras array with the available cameras.
        var cameras: [AVCaptureDevice] = []
        if let backCamera = backCameraDiscoverySession.devices.first {
            cameras.append(backCamera)
        }
        if let frontCamera = frontCameraDiscoverySession.devices.first {
            cameras.append(frontCamera)
        }
        // iPadOS supports connecting external cameras.
        if let externalCamera = externalCameraDiscoverSession.devices.first {
            cameras.append(externalCamera)
        }
        
#if !targetEnvironment(simulator)
        if cameras.isEmpty {
            fatalError("No camera devices are found on this system.")
        }
#endif
        return cameras
    }
    
    // MARK: - Enhanced Device Discovery
    
    /// Returns all available cameras including ultra-wide and telephoto lenses.
    var allCameras: [AVCaptureDevice] {
        var allDevices: [AVCaptureDevice] = []
        
        // Add all discovery session devices
        allDevices.append(contentsOf: backCameraDiscoverySession.devices)
        allDevices.append(contentsOf: frontCameraDiscoverySession.devices)
        allDevices.append(contentsOf: externalCameraDiscoverSession.devices)
        allDevices.append(contentsOf: ultraWideCameraDiscoverySession.devices)
        allDevices.append(contentsOf: telephotoCameraDiscoverySession.devices)
        allDevices.append(contentsOf: tripleCameraDiscoverySession.devices)
        
        // Remove duplicates while preserving order
        var uniqueDevices: [AVCaptureDevice] = []
        var seenIDs = Set<String>()
        
        for device in allDevices {
            if !seenIDs.contains(device.uniqueID) {
                seenIDs.insert(device.uniqueID)
                uniqueDevices.append(device)
            }
        }
        
        return uniqueDevices
    }
    
    /// Returns cameras that support cinematic video.
    var cinematicVideoCapableCameras: [AVCaptureDevice] {
        return allCameras.filter { device in
            device.formats.contains(where: { format in
                format.isMultiCamSupported
            })
        }
    }
    
    /// Returns cameras that support spatial video recording.
    var spatialVideoCapableCameras: [AVCaptureDevice] {
        return allCameras.filter { device in
            device.formats.contains(where: { format in
                format.isMultiCamSupported
            }) && device.activeDepthDataFormat != nil
        }
    }
    
    /// Returns optimal multi-camera device sets for different configurations.
    func getMultiCameraConfigurations() -> [MultiCameraConfiguration] {
        var configurations: [MultiCameraConfiguration] = []
        
        // Triple camera setup (if available)
        if let tripleCamera = tripleCameraDiscoverySession.devices.first,
           let frontCamera = frontCameraDiscoverySession.devices.first {
            var config = MultiCameraConfiguration(
                deviceIDs: [tripleCamera.uniqueID, frontCamera.uniqueID],
                primaryDeviceID: tripleCamera.uniqueID,
                layout: .sideBySide,
                synchronizationEnabled: true
            )
            config.devices = [tripleCamera, frontCamera]
            config.primaryDevice = tripleCamera
            configurations.append(config)
        }
        
        // Dual camera setup (back + front)
        if let backCamera = backCameraDiscoverySession.devices.first,
           let frontCamera = frontCameraDiscoverySession.devices.first {
            var config = MultiCameraConfiguration(
                deviceIDs: [backCamera.uniqueID, frontCamera.uniqueID],
                primaryDeviceID: backCamera.uniqueID,
                layout: .pictureInPicture,
                synchronizationEnabled: true
            )
            config.devices = [backCamera, frontCamera]
            config.primaryDevice = backCamera
            configurations.append(config)
        }
        
        // External camera setup (if available)
        if let externalCamera = externalCameraDiscoverSession.devices.first,
           let builtInCamera = backCameraDiscoverySession.devices.first {
            var config = MultiCameraConfiguration(
                deviceIDs: [externalCamera.uniqueID, builtInCamera.uniqueID],
                primaryDeviceID: builtInCamera.uniqueID,
                layout: .sideBySide,
                synchronizationEnabled: true
            )
            config.devices = [externalCamera, builtInCamera]
            config.primaryDevice = builtInCamera
            configurations.append(config)
        }
        
        return configurations
    }
    
    /// Returns the best camera for a specific use case.
    func getBestCamera(for useCase: CameraUseCase) -> AVCaptureDevice? {
        switch useCase {
        case .portrait:
            // Prefer telephoto for portraits
            return telephotoCameraDiscoverySession.devices.first ?? backCameraDiscoverySession.devices.first
        case .landscape:
            // Prefer ultra-wide for landscapes
            return ultraWideCameraDiscoverySession.devices.first ?? backCameraDiscoverySession.devices.first
        case .cinematic:
            // Prefer cameras that support cinematic video
            return cinematicVideoCapableCameras.first ?? backCameraDiscoverySession.devices.first
        case .spatial:
            // Prefer cameras that support spatial video
            return spatialVideoCapableCameras.first ?? backCameraDiscoverySession.devices.first
        case .general:
            // Default to back camera
            return backCameraDiscoverySession.devices.first
        }
    }
    
    enum CameraUseCase {
        case portrait
        case landscape
        case cinematic
        case spatial
        case general
    }
}
