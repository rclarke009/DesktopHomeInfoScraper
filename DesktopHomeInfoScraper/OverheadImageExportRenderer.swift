//
//  OverheadImageExportRenderer.swift
//  DesktopHomeInfoScraper
//
//  Renders a cropped overhead image (aspect-fit + zoom + pan + rotation)
//  into a square JPEG for export packages.
//

import AppKit
import Foundation
import SwiftUI

enum OverheadImageExportRenderer {
    /// Legacy reference used when pan was stored in points (pre-normalization).
    /// Used only for one-time migration paths in UI code.
    static let legacyPanReferencePoints: CGFloat = 500
    
    /// Output image resolution (pixels). Higher preserves more detail after cropping.
    static let defaultOutputPixels: Int = 2000
    
    static func renderOverheadJPEGData(
        imageURL: URL,
        zoomScale: Double,
        rotationDegrees: Double,
        panXNormalized: Double,
        panYNormalized: Double,
        outputPixels: Int = defaultOutputPixels
    ) async -> Data? {
        guard let nsImage = NSImage(contentsOf: imageURL) else { return nil }

        return await MainActor.run {
            let width = max(1, outputPixels)
            let height = max(1, outputPixels)
            let canvasSize = CGSize(width: width, height: height)

            let content = ZStack {
                Color.white
                OverheadImageTransformView(
                    image: nsImage,
                    containerSize: canvasSize,
                    zoomScale: CGFloat(max(0.05, zoomScale)),
                    panOffset: CGSize(
                        width: CGFloat(panXNormalized) * canvasSize.width,
                        height: CGFloat(panYNormalized) * canvasSize.height
                    ),
                    rotation: rotationDegrees,
                    cornerRadius: 0
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(canvasSize)
            renderer.scale = 1
            renderer.isOpaque = true

            guard let outNS = renderer.nsImage,
                  let tiff = outNS.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
                return nil
            }

            return jpeg
        }
    }
}
