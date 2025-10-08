/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Visual feedback system for camera operations.
*/

import Foundation
import SwiftUI

/// Manages user-facing feedback messages for camera operations
@Observable
class CameraFeedback {
    
    /// The current feedback message
    var message: String?
    
    /// The type of feedback being shown
    var type: FeedbackType = .info
    
    /// Whether feedback is currently visible
    var isVisible: Bool = false
    
    /// Auto-dismiss task
    private var dismissTask: Task<Void, Never>?
    
    /// Types of feedback messages
    enum FeedbackType {
        case info
        case success
        case warning
        case error
        
        var icon: String {
            switch self {
            case .info:
                return "info.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info:
                return .blue
            case .success:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            }
        }
    }
    
    /// Show a feedback message
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of feedback
    ///   - duration: How long to show the message (0 = indefinite)
    func show(_ message: String, type: FeedbackType = .info, duration: TimeInterval = 3.0) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()
        
        self.message = message
        self.type = type
        self.isVisible = true
        
        // Auto-dismiss if duration > 0
        if duration > 0 {
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                if !Task.isCancelled {
                    self.hide()
                }
            }
        }
    }
    
    /// Hide the current feedback message
    func hide() {
        dismissTask?.cancel()
        isVisible = false
        
        // Clear message after animation completes
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            if !isVisible {
                message = nil
            }
        }
    }
    
    /// Show success message
    func success(_ message: String, duration: TimeInterval = 2.0) {
        show(message, type: .success, duration: duration)
    }
    
    /// Show error message
    func error(_ message: String, duration: TimeInterval = 5.0) {
        show(message, type: .error, duration: duration)
    }
    
    /// Show warning message
    func warning(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .warning, duration: duration)
    }
    
    /// Show info message
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .info, duration: duration)
    }
}

/// SwiftUI view for displaying feedback messages
struct FeedbackBanner: View {
    let message: String
    let type: CameraFeedback.FeedbackType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        FeedbackBanner(message: "Dual camera mode enabled", type: .success)
        FeedbackBanner(message: "Switching cameras...", type: .info)
        FeedbackBanner(message: "Device is too hot for dual camera", type: .warning)
        FeedbackBanner(message: "Failed to enable dual camera mode", type: .error)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

