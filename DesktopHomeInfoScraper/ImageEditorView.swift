//
//  ImageEditorView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData

struct ImageEditorView: View {
    let imagePath: String
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var image: NSImage?
    @State private var scalePixelsPerFoot: Double = 0
    @State private var rotation: Double = 0
    @State private var showingScaleDialog = false
    @State private var scaleStartPoint: CGPoint?
    @State private var scaleEndPoint: CGPoint?
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var lastPanOffset: CGSize = .zero
    @State private var isMeasuringScale: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with Done button
                HStack {
                    Text("Edit Property Image")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(zoomScale > 1.8)
                }
                .padding(.horizontal)
                
                // Controls section
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        // Zoom Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zoom")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button("Zoom Out") {
                                        zoomScale = max(0.5, zoomScale - 0.25)
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 80)
                                    
                                    Button("Zoom In") {
                                        let newZoom = min(5.0, zoomScale + 0.25)
                                        zoomScale = newZoom
                                        lastZoomScale = newZoom
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 80)
                                }
                                
                                HStack {
                                    Text("Current: \(Int(zoomScale * 100))%")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Button("Reset") {
                                        zoomScale = 1.0
                                        lastZoomScale = 1.0
                                        panOffset = .zero
                                        lastPanOffset = .zero
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 60)
                                }
                                
                                // Zoom warning
                                if zoomScale > 1.8 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Zoom too close - building may be cut off")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        
                        // Rotation Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rotation")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button("Rotate Left") {
                                        rotation -= 90
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 80)
                                    
                                    Button("Rotate Right") {
                                        rotation += 90
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 80)
                                }
                                
                                HStack {
                                    Text("Current: \(Int(rotation))°")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Button("Reset") {
                                        rotation = 0
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minWidth: 60)
                                }
                            }
                        }
                        
                        // Scale Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scale Reference")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Scale Measurement Mode", isOn: $isMeasuringScale)
                                    .font(.subheadline)
                                
                                Text(isMeasuringScale ? "Drag across a known dimension (e.g., 10 feet)" : "Enable measurement mode to set scale")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if scalePixelsPerFoot > 0 {
                                    HStack {
                                        Text("Scale: \(String(format: "%.2f", scalePixelsPerFoot)) pixels/foot")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                    }
                                }
                                
                                if scalePixelsPerFoot > 0 {
                                    HStack {
                                        Text("Known distance (feet):")
                                            .font(.subheadline)
                                        
                                        TextField("Enter distance", value: $scalePixelsPerFoot, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 80)
                                        
                                        Button("Set Scale") {
                                            setScale()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                        
                        // Image Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Image Information")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                if let sourceName = job.sourceName {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Source:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(sourceName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let sourceUrl = job.sourceUrl {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("URL:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Link(sourceUrl, destination: URL(string: sourceUrl) ?? URL(string: "https://example.com")!)
                                            .font(.caption)
                                    }
                                }
                                
                                if let parcelId = job.parcelId {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Parcel ID:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(parcelId)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Main Image Display - Full Width
                if let image = image {
                    VStack(spacing: 12) {
                        // Image container that maintains aspect ratio with zoom/pan/pinch support
                        GeometryReader { geometry in
                            ZStack {
                                // Background to ensure gestures work across entire area
                                Color.clear
                                    .contentShape(Rectangle())
                                
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(zoomScale)
                                    .offset(panOffset)
                                    .rotationEffect(.degrees(rotation))
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                    )
                                
                                // Scale measurement line overlay
                                if isMeasuringScale, let start = scaleStartPoint, let end = scaleEndPoint {
                                    Path { path in
                                        path.move(to: start)
                                        path.addLine(to: end)
                                    }
                                    .stroke(Color.red, lineWidth: 2)
                                    .overlay(
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .position(start)
                                    )
                                    .overlay(
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .position(end)
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastZoomScale * value
                                        zoomScale = max(0.5, min(5.0, newScale))
                                    }
                                    .onEnded { _ in
                                        lastZoomScale = zoomScale
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if isMeasuringScale {
                                            // Scale measurement mode
                                            if scaleStartPoint == nil {
                                                scaleStartPoint = value.startLocation
                                            }
                                            scaleEndPoint = value.location
                                        } else {
                                            // Pan mode
                                            panOffset = CGSize(
                                                width: lastPanOffset.width + value.translation.width,
                                                height: lastPanOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        if isMeasuringScale {
                                            if let start = scaleStartPoint, let end = scaleEndPoint {
                                                calculateScale(start: start, end: end)
                                            }
                                            scaleStartPoint = nil
                                            scaleEndPoint = nil
                                        } else {
                                            lastPanOffset = panOffset
                                        }
                                    }
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: 600) // Full width, reasonable height
                        .clipped()
                        
                        // Scale Reference Display
                        if scalePixelsPerFoot > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "ruler")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Scale: \(String(format: "%.1f", scalePixelsPerFoot)) pixels per foot")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
                        // Instructions
                        HStack {
                            Image(systemName: "hand.draw")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(isMeasuringScale ? "Drag to measure distance" : "Pinch to zoom • Drag to pan • Toggle measurement mode to set scale")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Failed to load image")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .frame(minWidth: 1400)
            .padding(.vertical)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        image = NSImage(contentsOfFile: imagePath)
        
        // Load saved zoom and rotation values
        zoomScale = CGFloat(job.zoomScale)
        lastZoomScale = zoomScale
        panOffset = .zero
        lastPanOffset = .zero
        rotation = job.rotation
        if job.scalePixelsPerFoot > 0 {
            scalePixelsPerFoot = job.scalePixelsPerFoot
        }
    }
    
    private func calculateScale(start: CGPoint, end: CGPoint) {
        let _ = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        // This is a placeholder calculation - in reality you'd need to know the actual distance
        // For now, we'll just show the dialog to enter the known distance
        showingScaleDialog = true
    }
    
    private func setScale() {
        // This would calculate the actual scale based on the known distance
        // For now, we'll just save the value
        job.scalePixelsPerFoot = scalePixelsPerFoot
    }
    
    private func saveChanges() {
        print("MYDEBUG → [ImageEditorView] Saving changes - Zoom: \(zoomScale), Rotation: \(rotation), Scale: \(scalePixelsPerFoot)")
        
        job.scalePixelsPerFoot = scalePixelsPerFoot
        job.zoomScale = Double(zoomScale)  // Convert CGFloat to Double for Core Data
        job.rotation = rotation
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
            print("MYDEBUG → [ImageEditorView] Successfully saved image changes")
        } catch {
            print("MYDEBUG → [ImageEditorView] Failed to save image changes: \(error)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.sourceName = "Hillsborough County Property Appraiser"
    job.sourceUrl = "https://example.com"
    job.parcelId = "12345-678-90"
    
    return ImageEditorView(
        imagePath: "/path/to/image.jpg",
        job: job
    )
    .environment(\.managedObjectContext, context)
}
