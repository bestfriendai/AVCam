/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that renders simultaneous previews for the primary and secondary camera feeds using an `AVCaptureMultiCamSession`.
*/

import SwiftUI
import AVFoundation
import UIKit

struct MultiCamPreview: UIViewRepresentable {

    let configuration: MultiCamPreviewConfiguration
    let layout: MultiCameraConfiguration.MultiCamLayout
    
    init(configuration: MultiCamPreviewConfiguration, layout: MultiCameraConfiguration.MultiCamLayout = .pictureInPicture) {
        self.configuration = configuration
        self.layout = layout
    }

    func makeUIView(context: Context) -> MultiCamPreviewView {
        let view = MultiCamPreviewView()
        view.configure(with: configuration, layout: layout)
        return view
    }

    func updateUIView(_ uiView: MultiCamPreviewView, context: Context) {
        uiView.configure(with: configuration, layout: layout)
    }
}

final class MultiCamPreviewView: UIView {

    private var primaryLayer: AVCaptureVideoPreviewLayer?
    private var secondaryLayer: AVCaptureVideoPreviewLayer?
    private weak var session: AVCaptureMultiCamSession?
    private var primaryConnection: AVCaptureConnection?
    private var secondaryConnection: AVCaptureConnection?
    private var currentLayout: MultiCameraConfiguration.MultiCamLayout = .pictureInPicture

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with configuration: MultiCamPreviewConfiguration, layout: MultiCameraConfiguration.MultiCamLayout) {
        guard configuration.session != session ||
                primaryConnection?.inputPorts.first !== configuration.primaryPort ||
                secondaryConnection?.inputPorts.first !== configuration.secondaryPort ||
                currentLayout != layout else {
            // Configuration already matches the current layout.
            return
        }

        currentLayout = layout
        let session = configuration.session
        session.beginConfiguration()

        // Tear down any existing connections before installing new ones.
        if let primaryConnection {
            session.removeConnection(primaryConnection)
            self.primaryConnection = nil
        }
        if let secondaryConnection {
            session.removeConnection(secondaryConnection)
            self.secondaryConnection = nil
        }

        self.session = session

        installPrimaryLayer(using: session, port: configuration.primaryPort)
        installSecondaryLayer(using: session, port: configuration.secondaryPort)

        session.commitConfiguration()

        setNeedsLayout()
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
        
        // Configure mirroring before adding to session
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
        case .sideBySide:
            layoutSideBySide()
        case .grid:
            layoutGrid()
        case .custom:
            layoutCustom()
        }
    }
    
    private func layoutPictureInPicture() {
        primaryLayer?.frame = bounds

        guard let secondaryLayer else { return }
        let inset: CGFloat = 16
        let width = bounds.width * 0.3
        let height = width * (4.0 / 3.0)
        secondaryLayer.frame = CGRect(x: bounds.maxX - width - inset,
                                      y: inset,
                                      width: width,
                                      height: height)
    }
    
    private func layoutSideBySide() {
        guard let secondaryLayer else {
            primaryLayer?.frame = bounds
            return
        }
        
        let halfWidth = bounds.width / 2
        primaryLayer?.frame = CGRect(x: 0, y: 0, width: halfWidth, height: bounds.height)
        secondaryLayer.frame = CGRect(x: halfWidth, y: 0, width: halfWidth, height: bounds.height)
    }
    
    private func layoutGrid() {
        guard let secondaryLayer else {
            primaryLayer?.frame = bounds
            return
        }

        let halfHeight = bounds.height / 2
        // Front camera (secondary) at TOP, Back camera (primary) at BOTTOM
        secondaryLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        primaryLayer?.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)
    }
    
    private func layoutCustom() {
        // Custom layout could be configured based on user preferences
        // For now, default to picture-in-picture
        layoutPictureInPicture()
    }
}
