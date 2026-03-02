//
//  OverheadImageTransformView.swift
//  DesktopHomeInfoScraper
//
//  Shared overhead image presentation used by both on-screen editing
//  and export rendering so transform behavior stays consistent.
//

import AppKit
import SwiftUI

struct OverheadImageTransformView: View {
    let image: NSImage
    let containerSize: CGSize
    let zoomScale: CGFloat
    let panOffset: CGSize
    let rotation: Double
    var cornerRadius: CGFloat = 8
    var borderColor: Color = .clear
    var borderLineWidth: CGFloat = 0

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(zoomScale)
            .offset(panOffset)
            .rotationEffect(.degrees(rotation))
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderLineWidth)
            )
    }
}
