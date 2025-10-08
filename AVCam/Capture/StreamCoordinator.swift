/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Multi-camera stream synchronization and coordination.
*/

import AVFoundation
import Combine
import os.log

/// Multi-camera stream synchronization and coordination.
final class StreamCoordinator: ObservableObject {
    
    private let logger = Logger(subsystem: "com.apple.AVCam", category: "StreamCoordinator")
    
    @Published private(set) var activeStreams: [VideoStream] = []
    @Published private(set) var isSynchronized = false
    
    private var synchronizationTimer: Timer?
    private let syncInterval: TimeInterval = 0.1
    
    func addStream(_ stream: VideoStream) {
        activeStreams.append(stream)
        updateSynchronization()
    }
    
    func removeStream(id: UUID) {
        activeStreams.removeAll { $0.id == id }
        updateSynchronization()
    }
    
    func startSynchronization() {
        stopSynchronization()
        
        synchronizationTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.synchronizeStreams()
        }
    }
    
    func stopSynchronization() {
        synchronizationTimer?.invalidate()
        synchronizationTimer = nil
        isSynchronized = false
    }
    
    private func synchronizeStreams() {
        guard !activeStreams.isEmpty else { return }
        
        // Get the highest priority stream as the master
        guard let masterStream = activeStreams.max(by: { $0.priority.rawValue < $1.priority.rawValue }) else {
            return
        }
        
        // Synchronize other streams to the master
        for stream in activeStreams where stream.id != masterStream.id {
            synchronizeStream(stream, to: masterStream)
        }
        
        isSynchronized = true
    }
    
    private func synchronizeStream(_ stream: VideoStream, to masterStream: VideoStream) {
        // Implementation would synchronize timing, frame rates, etc.
        // This is a placeholder for the actual synchronization logic
    }
    
    private func updateSynchronization() {
        if activeStreams.count > 1 {
            startSynchronization()
        } else {
            stopSynchronization()
        }
    }
    
    func getStreamPriority(for device: AVCaptureDevice) -> VideoStream.StreamPriority {
        switch device.deviceType {
        case .builtInTripleCamera:
            return .high
        case .builtInDualCamera, .builtInDualWideCamera:
            return .medium
        default:
            return .low
        }
    }
}