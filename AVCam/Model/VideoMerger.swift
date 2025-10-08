/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Utility for merging two videos vertically (top/bottom split screen).
*/

import AVFoundation
import UIKit
import os.log

/// Merges two videos into a single split-screen video
actor VideoMerger {
    
    private let logger = Logger(subsystem: "com.apple.AVCam", category: "VideoMerger")
    
    /// Merges two videos vertically (top video on top, bottom video on bottom)
    /// - Parameters:
    ///   - topVideoURL: URL of the video to place at the top
    ///   - bottomVideoURL: URL of the video to place at the bottom
    ///   - outputURL: URL where the merged video will be saved
    /// - Returns: URL of the merged video
    func mergeVideosVertically(topVideoURL: URL, bottomVideoURL: URL, outputURL: URL) async throws -> URL {
        logger.info("Starting vertical video merge...")
        logger.info("Top video: \(topVideoURL.lastPathComponent)")
        logger.info("Bottom video: \(bottomVideoURL.lastPathComponent)")
        
        // Load the video assets
        let topAsset = AVURLAsset(url: topVideoURL)
        let bottomAsset = AVURLAsset(url: bottomVideoURL)
        
        // Get video tracks
        guard let topVideoTrack = try await topAsset.loadTracks(withMediaType: .video).first else {
            logger.error("Failed to load top video track")
            throw VideoMergerError.invalidVideoTrack
        }
        
        guard let bottomVideoTrack = try await bottomAsset.loadTracks(withMediaType: .video).first else {
            logger.error("Failed to load bottom video track")
            throw VideoMergerError.invalidVideoTrack
        }
        
        // Get video properties
        let topSize = try await topVideoTrack.load(.naturalSize)
        let bottomSize = try await bottomVideoTrack.load(.naturalSize)
        let topDuration = try await topAsset.load(.duration)
        let bottomDuration = try await bottomAsset.load(.duration)
        
        // Use the shorter duration
        let duration = min(topDuration, bottomDuration)
        
        logger.info("Top video size: \(topSize.width)x\(topSize.height)")
        logger.info("Bottom video size: \(bottomSize.width)x\(bottomSize.height)")
        logger.info("Duration: \(duration.seconds) seconds")
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video tracks to composition
        guard let compositionTopTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            logger.error("Failed to create top composition track")
            throw VideoMergerError.compositionFailed
        }
        
        guard let compositionBottomTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            logger.error("Failed to create bottom composition track")
            throw VideoMergerError.compositionFailed
        }
        
        // Insert video segments
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        try compositionTopTrack.insertTimeRange(timeRange, of: topVideoTrack, at: .zero)
        try compositionBottomTrack.insertTimeRange(timeRange, of: bottomVideoTrack, at: .zero)
        
        // Add audio from both videos
        if let topAudioTrack = try await topAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: topAudioTrack, at: .zero)
            logger.info("Added top audio track")
        }
        
        if let bottomAudioTrack = try await bottomAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack2 = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack2.insertTimeRange(timeRange, of: bottomAudioTrack, at: .zero)
            logger.info("Added bottom audio track")
        }
        
        // Create video composition for layout
        let videoComposition = AVMutableVideoComposition()
        
        // Use the width of the wider video, and sum the heights
        let outputWidth = max(topSize.width, bottomSize.width)
        let outputHeight = topSize.height + bottomSize.height
        videoComposition.renderSize = CGSize(width: outputWidth, height: outputHeight)
        
        // Set frame rate (use the top video's frame rate)
        let topFrameRate = try await topVideoTrack.load(.nominalFrameRate)
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(topFrameRate))
        
        logger.info("Output size: \(outputWidth)x\(outputHeight)")
        logger.info("Frame rate: \(topFrameRate) fps")
        
        // Create layer instructions for positioning
        let topInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTopTrack)
        let bottomInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionBottomTrack)
        
        // Position top video at the top
        let topTransform = CGAffineTransform(translationX: 0, y: 0)
        topInstruction.setTransform(topTransform, at: .zero)
        
        // Position bottom video at the bottom
        let bottomTransform = CGAffineTransform(translationX: 0, y: topSize.height)
        bottomInstruction.setTransform(bottomTransform, at: .zero)
        
        // Create main instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = timeRange
        mainInstruction.layerInstructions = [topInstruction, bottomInstruction]
        
        videoComposition.instructions = [mainInstruction]
        
        // Export the composition
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            logger.error("Failed to create export session")
            throw VideoMergerError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        
        logger.info("Starting export to: \(outputURL.lastPathComponent)")
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            logger.info("✅ Video merge completed successfully")
            return outputURL
        case .failed:
            logger.error("❌ Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            throw VideoMergerError.exportFailed
        case .cancelled:
            logger.error("❌ Export cancelled")
            throw VideoMergerError.exportCancelled
        default:
            logger.error("❌ Export failed with status: \(exportSession.status.rawValue)")
            throw VideoMergerError.exportFailed
        }
    }
}

/// Errors that can occur during video merging
enum VideoMergerError: LocalizedError {
    case invalidVideoTrack
    case compositionFailed
    case exportFailed
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidVideoTrack:
            return "Invalid video track"
        case .compositionFailed:
            return "Failed to create video composition"
        case .exportFailed:
            return "Failed to export merged video"
        case .exportCancelled:
            return "Video export was cancelled"
        }
    }
}

