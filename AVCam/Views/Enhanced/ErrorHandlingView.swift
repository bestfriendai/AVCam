/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Comprehensive error handling and recovery UI with user-friendly messaging.
*/

import SwiftUI
import AVFoundation

// MARK: - Error Handling Manager

class ErrorHandlingManager: ObservableObject {
    @Published var currentError: CameraError?
    @Published var errorHistory: [ErrorEntry] = []
    @Published var showErrorSheet = false
    @Published var showErrorBanner = false
    
    func handle(_ error: CameraError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.errorHistory.append(ErrorEntry(error: error, timestamp: Date()))
            self.showErrorBanner = true
            
            // Auto-hide banner after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.showErrorBanner = false
            }
        }
    }
    
    func dismissError() {
        currentError = nil
        showErrorBanner = false
        showErrorSheet = false
    }
    
    func retryLastAction() {
        // Implement retry logic
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
}

// MARK: - Error Entry

struct ErrorEntry: Identifiable {
    let id = UUID()
    let error: CameraError
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: CameraError
    let onDismiss: () -> Void
    let onRetry: () -> Void
    let onDetails: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                errorIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                    )
                    
                    Button("Details") {
                        onDetails()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                    )
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(error.severity.color.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var errorIcon: some View {
        Image(systemName: error.icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.2))
            )
    }
}

// MARK: - Error Sheet

struct ErrorSheet: View {
    let error: CameraError
    let onDismiss: () -> Void
    let onRetry: () -> Void
    let onReport: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Error header
                    errorHeader
                    
                    // Error details
                    errorDetails
                    
                    // Suggested actions
                    suggestedActions
                    
                    // Technical details
                    technicalDetails
                }
                .padding()
            }
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Report") {
                        onReport()
                    }
                }
            }
        }
    }
    
    private var errorHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: error.icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(error.severity.color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(error.severity.color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(error.severity.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    private var errorDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 16, weight: .semibold))
            
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var suggestedActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Actions")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 8) {
                ForEach(error.suggestedActions, id: \.self) { action in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        Text(action)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var technicalDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Details")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 8) {
                DetailRow(title: "Error Code", value: error.code)
                DetailRow(title: "Category", value: error.category.description)
                DetailRow(title: "Timestamp", value: DateFormatter.errorFormatter.string(from: Date()))
                DetailRow(title: "Device", value: UIDevice.current.model)
                DetailRow(title: "iOS Version", value: UIDevice.current.systemVersion)
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recovery View

struct RecoveryView: View {
    let error: CameraError
    let onRetry: () -> Void
    let onReset: () -> Void
    let onContactSupport: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Recovery icon
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            // Recovery message
            VStack(spacing: 8) {
                Text("Camera Needs Recovery")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("The camera encountered an issue and needs to be reset. Choose an option below to continue.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Recovery options
            VStack(spacing: 12) {
                Button("Retry Last Action") {
                    onRetry()
                }
                .buttonStyle(RecoveryButtonStyle(primary: true))
                
                Button("Reset Camera") {
                    onReset()
                }
                .buttonStyle(RecoveryButtonStyle(primary: false))
                
                Button("Contact Support") {
                    onContactSupport()
                }
                .buttonStyle(RecoveryButtonStyle(primary: false))
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(radius: 10)
    }
}

// MARK: - Recovery Button Style

struct RecoveryButtonStyle: ButtonStyle {
    let primary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(primary ? .white : .blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(primary ? Color.blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: primary ? 0 : 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Error History View

struct ErrorHistoryView: View {
    @ObservedObject var errorManager: ErrorHandlingManager
    
    var body: some View {
        NavigationView {
            List {
                if errorManager.errorHistory.isEmpty {
                    Text("No errors recorded")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(errorManager.errorHistory) { entry in
                        ErrorHistoryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Error History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        errorManager.clearErrorHistory()
                    }
                    .disabled(errorManager.errorHistory.isEmpty)
                }
            }
        }
    }
}

// MARK: - Error History Row

struct ErrorHistoryRow: View {
    let entry: ErrorEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.error.title)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Text(entry.timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.error.localizedDescription)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Camera Error Extensions

extension CameraError {
    var title: String {
        switch self {
        case .videoDeviceUnavailable:
            return "Camera Unavailable"
        case .audioDeviceUnavailable:
            return "Microphone Unavailable"
        case .addInputFailed:
            return "Input Setup Failed"
        case .addOutputFailed:
            return "Output Setup Failed"
        case .setupFailed:
            return "Camera Setup Failed"
        case .deviceChangeFailed:
            return "Device Change Failed"
        case .multiCamConfigurationFailed:
            return "Multi-Camera Setup Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .videoDeviceUnavailable, .audioDeviceUnavailable:
            return "exclamationmark.triangle.fill"
        case .addInputFailed, .addOutputFailed, .setupFailed:
            return "gear.badge.exclamationmark"
        case .deviceChangeFailed:
            return "camera.badge.exclamationmark"
        case .multiCamConfigurationFailed:
            return "rectangle.stack.badge.exclamationmark"
        }
    }
    
    var code: String {
        switch self {
        case .videoDeviceUnavailable:
            return "CAM_001"
        case .audioDeviceUnavailable:
            return "CAM_002"
        case .addInputFailed:
            return "CAM_003"
        case .addOutputFailed:
            return "CAM_004"
        case .setupFailed:
            return "CAM_005"
        case .deviceChangeFailed:
            return "CAM_006"
        case .multiCamConfigurationFailed:
            return "CAM_007"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .videoDeviceUnavailable, .audioDeviceUnavailable:
            return .critical
        case .addInputFailed, .addOutputFailed, .setupFailed:
            return .high
        case .deviceChangeFailed, .multiCamConfigurationFailed:
            return .medium
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .videoDeviceUnavailable, .audioDeviceUnavailable:
            return .hardware
        case .addInputFailed, .addOutputFailed, .setupFailed:
            return .configuration
        case .deviceChangeFailed, .multiCamConfigurationFailed:
            return .runtime
        }
    }
    
    var suggestedActions: [String] {
        switch self {
        case .videoDeviceUnavailable:
            return [
                "Check if camera is being used by another app",
                "Close other camera apps and try again",
                "Restart the device if the issue persists"
            ]
        case .audioDeviceUnavailable:
            return [
                "Check if microphone is being used by another app",
                "Ensure microphone permissions are granted",
                "Check device settings for microphone access"
            ]
        case .addInputFailed, .addOutputFailed:
            return [
                "Restart the camera session",
                "Check device compatibility",
                "Update to the latest iOS version"
            ]
        case .setupFailed:
            return [
                "Restart the app",
                "Check camera permissions",
                "Reset camera settings"
            ]
        case .deviceChangeFailed:
            return [
                "Try switching cameras again",
                "Restart the camera session",
                "Reset camera configuration"
            ]
        case .multiCamConfigurationFailed:
            return [
                "Check device supports multi-camera",
                "Ensure sufficient system resources",
                "Close other apps and try again"
            ]
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case low
    case medium
    case high
    case critical
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Error Category

enum ErrorCategory {
    case hardware
    case configuration
    case runtime
    case permission
    case network
    
    var description: String {
        switch self {
        case .hardware: return "Hardware"
        case .configuration: return "Configuration"
        case .runtime: return "Runtime"
        case .permission: return "Permission"
        case .network: return "Network"
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let errorFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    ErrorBanner(
        error: .videoDeviceUnavailable,
        onDismiss: {},
        onRetry: {},
        onDetails: {}
    )
}