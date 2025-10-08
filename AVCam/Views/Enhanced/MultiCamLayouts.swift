/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Enhanced multi-camera preview layouts with adaptive positioning and transitions.
*/

import SwiftUI
import AVFoundation

// MARK: - Multi-Camera Layout Manager

struct MultiCamLayoutManager: View {
    let configuration: MultiCamPreviewConfiguration
    @State private var selectedLayout: MultiCamLayout = .pictureInPicture
    @State private var isTransitioning = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Primary camera feed (full screen)
                MultiCamPreview(configuration: configuration)
                    .ignoresSafeArea()
                
                // Secondary camera feed with layout
                secondaryPreview(geometry: geometry)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
                
                // Layout controls
                layoutControls
                    .position(x: geometry.size.width - 80, y: 100)
            }
        }
        .onChange(of: selectedLayout) { _, _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isTransitioning.toggle()
            }
        }
    }
    
    @ViewBuilder
    private func secondaryPreview(geometry: GeometryProxy) -> some View {
        switch selectedLayout {
        case .pictureInPicture:
            pictureInPictureView(geometry: geometry)
        case .splitScreen:
            splitScreenView(geometry: geometry)
        case .overlay:
            overlayView(geometry: geometry)
        case .stacked:
            stackedView(geometry: geometry)
        }
    }
    
    private func pictureInPictureView(geometry: GeometryProxy) -> some View {
        MultiCamPreview(configuration: configuration)
            .frame(width: geometry.size.width * 0.3, height: geometry.size.width * 0.3 * 4/3)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(radius: 10)
            .position(
                x: geometry.size.width - (geometry.size.width * 0.15) - 20,
                y: (geometry.size.width * 0.3 * 4/3) / 2 + 80
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Allow dragging to reposition
                    }
            )
    }
    
    private func splitScreenView(geometry: GeometryProxy) -> some View {
        HStack(spacing: 2) {
            MultiCamPreview(configuration: configuration)
                .frame(maxWidth: .infinity)
            MultiCamPreview(configuration: configuration)
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea()
    }
    
    private func overlayView(geometry: GeometryProxy) -> some View {
        MultiCamPreview(configuration: configuration)
            .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.5)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func stackedView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            MultiCamPreview(configuration: configuration)
                .frame(maxHeight: .infinity)
            MultiCamPreview(configuration: configuration)
                .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
    
    private var layoutControls: some View {
        VStack(spacing: 12) {
            ForEach(MultiCamLayout.allCases, id: \.self) { layout in
                Button {
                    selectedLayout = layout
                } label: {
                    Image(systemName: layout.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedLayout == layout ? .blue : .white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Circle()
                                        .stroke(selectedLayout == layout ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .blur(radius: 1)
        )
    }
}

// MARK: - Multi-Camera Layout Types

enum MultiCamLayout: CaseIterable {
    case pictureInPicture
    case splitScreen
    case overlay
    case stacked
    
    var icon: String {
        switch self {
        case .pictureInPicture:
            return "rectangle.inset.filled"
        case .splitScreen:
            return "rectangle.split.2x1"
        case .overlay:
            return "rectangle.stack"
        case .stacked:
            return "rectangle.split.2x1.fill"
        }
    }
}

// MARK: - Enhanced Multi-Cam Preview

struct EnhancedMultiCamPreview: UIViewRepresentable {
    let configuration: MultiCamPreviewConfiguration
    let layout: MultiCamLayout
    let animationDuration: TimeInterval
    
    init(configuration: MultiCamPreviewConfiguration, layout: MultiCamLayout = .pictureInPicture, animationDuration: TimeInterval = 0.3) {
        self.configuration = configuration
        self.layout = layout
        self.animationDuration = animationDuration
    }
    
    func makeUIView(context: Context) -> EnhancedMultiCamPreviewView {
        let view = EnhancedMultiCamPreviewView()
        view.configure(with: configuration, layout: layout, animationDuration: animationDuration)
        return view
    }
    
    func updateUIView(_ uiView: EnhancedMultiCamPreviewView, context: Context) {
        uiView.configure(with: configuration, layout: layout, animationDuration: animationDuration)
    }
}

final class EnhancedMultiCamPreviewView: UIView {
    
    private var primaryLayer: AVCaptureVideoPreviewLayer?
    private var secondaryLayer: AVCaptureVideoPreviewLayer?
    private weak var session: AVCaptureMultiCamSession?
    private var primaryConnection: AVCaptureConnection?
    private var secondaryConnection: AVCaptureConnection?
    private var currentLayout: MultiCamLayout = .pictureInPicture
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with configuration: MultiCamPreviewConfiguration, layout: MultiCamLayout, animationDuration: TimeInterval) {
        guard configuration.session != session ||
                primaryConnection?.inputPorts.first !== configuration.primaryPort ||
                secondaryConnection?.inputPorts.first !== configuration.secondaryPort ||
                currentLayout != layout else {
            return
        }
        
        let session = configuration.session
        session.beginConfiguration()
        
        // Clean up existing connections
        cleanupConnections(session: session)
        
        self.session = session
        self.currentLayout = layout
        
        // Install layers with animation
        UIView.animate(withDuration: animationDuration) {
            self.installPrimaryLayer(using: session, port: configuration.primaryPort)
            self.installSecondaryLayer(using: session, port: configuration.secondaryPort)
        }
        
        session.commitConfiguration()
        
        setNeedsLayout()
    }
    
    private func cleanupConnections(session: AVCaptureMultiCamSession) {
        if let primaryConnection {
            session.removeConnection(primaryConnection)
            self.primaryConnection = nil
        }
        if let secondaryConnection {
            session.removeConnection(secondaryConnection)
            self.secondaryConnection = nil
        }
    }
    
    private func installPrimaryLayer(using session: AVCaptureMultiCamSession, port: AVCaptureInput.Port) {
        if primaryLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
            layer.videoGravity = .resizeAspectFill
            primaryLayer = layer
            self.layer.addSublayer(layer)
        }
        
        guard let primaryLayer else { return }
        primaryLayer.setSessionWithNoConnection(session)
        
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: primaryLayer)
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = port.sourceDevicePosition == .front
        
        if session.canAddConnection(connection) {
            session.addConnection(connection)
            primaryConnection = connection
        }
    }
    
    private func installSecondaryLayer(using session: AVCaptureMultiCamSession, port: AVCaptureInput.Port) {
        if secondaryLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
            layer.videoGravity = .resizeAspectFill
            layer.masksToBounds = true
            layer.cornerRadius = 12
            layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            layer.borderWidth = 1
            secondaryLayer = layer
            self.layer.addSublayer(layer)
        }
        
        guard let secondaryLayer else { return }
        secondaryLayer.setSessionWithNoConnection(session)
        
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: secondaryLayer)
        
        // Configure mirroring before adding to session
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = port.sourceDevicePosition == .front
        
        if session.canAddConnection(connection) {
            session.addConnection(connection)
            secondaryConnection = connection
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        switch currentLayout {
        case .pictureInPicture:
            layoutPictureInPicture()
        case .splitScreen:
            layoutSplitScreen()
        case .overlay:
            layoutOverlay()
        case .stacked:
            layoutStacked()
        }
        
        primaryLayer?.frame = bounds
    }
    
    private func layoutPictureInPicture() {
        guard let secondaryLayer else { return }
        let inset: CGFloat = 16
        let width = bounds.width * 0.3
        let height = width * (4.0 / 3.0)
        secondaryLayer.frame = CGRect(x: bounds.maxX - width - inset,
                                      y: inset,
                                      width: width,
                                      height: height)
    }
    
    private func layoutSplitScreen() {
        guard let secondaryLayer else { return }
        let halfWidth = bounds.width / 2
        primaryLayer?.frame = CGRect(x: 0, y: 0, width: halfWidth, height: bounds.height)
        secondaryLayer.frame = CGRect(x: halfWidth, y: 0, width: halfWidth, height: bounds.height)
    }
    
    private func layoutOverlay() {
        guard let secondaryLayer else { return }
        let overlayWidth = bounds.width * 0.5
        let overlayHeight = bounds.height * 0.5
        let overlayX = (bounds.width - overlayWidth) / 2
        let overlayY = (bounds.height - overlayHeight) / 2
        secondaryLayer.frame = CGRect(x: overlayX, y: overlayY, width: overlayWidth, height: overlayHeight)
        secondaryLayer.cornerRadius = 20
    }
    
    private func layoutStacked() {
        guard let secondaryLayer else { return }
        let halfHeight = bounds.height / 2
        primaryLayer?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        secondaryLayer.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)
    }
}

#Preview {
    MultiCamLayoutManager(configuration: MultiCamPreviewConfiguration(
        session: AVCaptureMultiCamSession(),
        primaryPort: AVCaptureInput.Port(),
        secondaryPort: AVCaptureInput.Port()
    ))
}