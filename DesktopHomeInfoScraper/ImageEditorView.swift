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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
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
                }
                
                // Image Display
                if let image = image {
                    VStack(spacing: 12) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .rotationEffect(.degrees(rotation))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scaleStartPoint == nil {
                                            scaleStartPoint = value.startLocation
                                        }
                                        scaleEndPoint = value.location
                                    }
                                    .onEnded { _ in
                                        if let start = scaleStartPoint, let end = scaleEndPoint {
                                            calculateScale(start: start, end: end)
                                        }
                                        scaleStartPoint = nil
                                        scaleEndPoint = nil
                                    }
                            )
                        
                        // Scale Line Visualization
                        if let start = scaleStartPoint, let end = scaleEndPoint {
                            GeometryReader { geometry in
                                Path { path in
                                    let startPoint = CGPoint(
                                        x: start.x * geometry.size.width,
                                        y: start.y * geometry.size.height
                                    )
                                    let endPoint = CGPoint(
                                        x: end.x * geometry.size.width,
                                        y: end.y * geometry.size.height
                                    )
                                    
                                    path.move(to: startPoint)
                                    path.addLine(to: endPoint)
                                }
                                .stroke(Color.red, lineWidth: 2)
                            }
                            .frame(height: 400)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 400)
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
                }
                
                // Controls
                VStack(spacing: 16) {
                    // Rotation Controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rotation")
                            .font(.headline)
                        
                        HStack {
                            Button("Rotate Left") {
                                rotation -= 90
                            }
                            .buttonStyle(.bordered)
                            
                            Text("\(Int(rotation))°")
                                .frame(minWidth: 40)
                            
                            Button("Rotate Right") {
                                rotation += 90
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Reset") {
                                rotation = 0
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Scale Controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scale Reference")
                            .font(.headline)
                        
                        HStack {
                            Text("Drag across a known dimension (e.g., 10 feet)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if scalePixelsPerFoot > 0 {
                                Text("\(String(format: "%.2f", scalePixelsPerFoot)) pixels/foot")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if scalePixelsPerFoot > 0 {
                            HStack {
                                Text("Known distance (feet):")
                                
                                TextField("Enter distance", value: $scalePixelsPerFoot, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                
                                Button("Set Scale") {
                                    setScale()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    // Image Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let sourceName = job.sourceName {
                                HStack {
                                    Text("Source:")
                                        .fontWeight(.medium)
                                    Text(sourceName)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let sourceUrl = job.sourceUrl {
                                HStack {
                                    Text("URL:")
                                        .fontWeight(.medium)
                                    Link(sourceUrl, destination: URL(string: sourceUrl) ?? URL(string: "https://example.com")!)
                                        .font(.caption)
                                }
                            }
                            
                            if let parcelId = job.parcelId {
                                HStack {
                                    Text("Parcel ID:")
                                        .fontWeight(.medium)
                                    Text(parcelId)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .frame(width: 700, height: 800)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        image = NSImage(contentsOfFile: imagePath)
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
        job.scalePixelsPerFoot = scalePixelsPerFoot
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save image changes: \(error)")
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
