//
//  JobDetailView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Foundation

struct JobDetailView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingImageEditor = false
    @State private var scalePixelsPerFoot: Double = 0
    @State private var showingExportOptions = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var lastPanOffset: CGSize = .zero
    @State private var showingImagePicker = false
    @State private var imageReplacementError: String?
    @State private var imageReplacementSuccess = false
    @State private var showingNamedStormEdit = false
    
    private func updateImageSettings(zoom: Double, rotation: Double) {
        job.zoomScale = zoom
        job.rotation = rotation
        
        do {
            try viewContext.save()
            print("✅ [JobDetailView] Successfully saved image settings - Zoom: \(zoom), Rotation: \(rotation)")
        } catch {
            print("❌ [JobDetailView] Failed to save image settings: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.jobId ?? "Unknown Job")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let clientName = job.clientName {
                        Text("Client: \(clientName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let phoneNumber = job.phoneNumber, !phoneNumber.isEmpty {
                        Text("Phone: \(phoneNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Status and Actions
                HStack {
                    StatusBadge(status: job.status ?? "unknown")
                    
                    Spacer()
                    
                    if job.status == "completed" {
                        Button("Advanced Edit") {
                            print("🔧 [JobDetailView] Advanced Edit button tapped for job: \(job.jobId ?? "Unknown")")
                            showingImageEditor = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    
                    if job.isApproved {
                        Button("Export Job Package") {
                            showingExportOptions = true
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                    }
                }
                .padding(.bottom, 8) // Add extra spacing to prevent overlap
                
                // Named Storm (when completed)
                if job.status == "completed" {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { showingNamedStormEdit = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: (job.namedStormName != nil && !(job.namedStormName ?? "").isEmpty) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor((job.namedStormName != nil && !(job.namedStormName ?? "").isEmpty) ? .green : .gray)
                                Image(systemName: "hurricane")
                                    .foregroundColor(.secondary)
                                Text("Named Storm")
                                    .font(.headline)
                                if let name = job.namedStormName, !name.isEmpty {
                                    Text("— \(name)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Approval Section (placed high so it stays visible)
                if job.status == "completed" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review & Approval")
                            .font(.headline)
                        
                        HStack {
                            if job.isApproved {
                                Button("Approved ✓") {
                                    toggleApproval()
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .disabled(job.overheadImagePath == nil)
                            } else {
                                Button("Approve Image") {
                                    toggleApproval()
                                }
                                .buttonStyle(BorderedProminentButtonStyle())
                                .disabled(job.overheadImagePath == nil)
                            }
                            
                            if !job.isApproved {
                                Button("Mark as No Data") {
                                    markAsNoData()
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .foregroundColor(.red)
                            }
                            
                            Spacer()
                        }
                        
                        if job.isApproved {
                            Text("This job is approved and ready for export")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // Main Content
                if job.status == "completed" && job.overheadImagePath != nil {
                    // Image Display
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Property Image")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text("Replace Image")
                                }
                                .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let imagePath = job.overheadImagePath,
                           let image = NSImage(contentsOfFile: imagePath) {
                            // Interactive image container with zoom/pan/pinch support
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
                                        .rotationEffect(.degrees(job.rotation))
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
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
                                            updateImageSettings(zoom: Double(zoomScale), rotation: job.rotation)
                                        }
                                )
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            panOffset = CGSize(
                                                width: lastPanOffset.width + value.translation.width,
                                                height: lastPanOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastPanOffset = panOffset
                                        }
                                )
                            }
                            .frame(minWidth: 300, maxWidth: 500, minHeight: 300, maxHeight: 500)
                            .clipped()
                            
                            // Image Editing Controls
                            VStack(spacing: 12) {
                                Text("Image Editing")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 20) {
                                    // Zoom Controls
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Zoom")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        HStack(spacing: 8) {
                                            Button("Zoom Out") {
                                                let newZoom = max(0.5, zoomScale - 0.25)
                                                zoomScale = newZoom
                                                lastZoomScale = newZoom
                                                updateImageSettings(zoom: Double(newZoom), rotation: job.rotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 80)
                                            
                                            Button("Zoom In") {
                                                let newZoom = min(5.0, zoomScale + 0.25)
                                                zoomScale = newZoom
                                                lastZoomScale = newZoom
                                                updateImageSettings(zoom: Double(newZoom), rotation: job.rotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 80)
                                        }
                                        
                                        Text("Current: \(String(format: "%.1fx", zoomScale))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Rotation Controls
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Rotation")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        HStack(spacing: 8) {
                                            Button("Rotate Left") {
                                                let newRotation = (job.rotation - 90).truncatingRemainder(dividingBy: 360)
                                                updateImageSettings(zoom: job.zoomScale, rotation: newRotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 100)
                                            
                                            Button("Rotate Right") {
                                                let newRotation = (job.rotation + 90).truncatingRemainder(dividingBy: 360)
                                                updateImageSettings(zoom: job.zoomScale, rotation: newRotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 100)
                                        }
                                        
                                        Text("Current: \(String(format: "%.0f°", job.rotation))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Reset Button
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Reset")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Button("Reset All") {
                                            zoomScale = 1.0
                                            lastZoomScale = 1.0
                                            panOffset = .zero
                                            lastPanOffset = .zero
                                            updateImageSettings(zoom: 1.0, rotation: 0.0)
                                        }
                                        .buttonStyle(.bordered)
                                        .frame(minWidth: 80)
                                        
                                        Text("Back to original")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Warning for high zoom
                                if zoomScale > 1.8 {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("Warning: High zoom level may cut off parts of the building")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                
                                // Gesture instructions
                                HStack {
                                    Image(systemName: "hand.draw")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Pinch to zoom • Drag to pan")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(4)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundColor(.gray)
                                        Text("Image not found")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                )
                                .cornerRadius(8)
                        }
                        
                        // Image Info
                        VStack(alignment: .leading, spacing: 8) {
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
                            
                            if job.scalePixelsPerFoot > 0 {
                                HStack {
                                    Text("Scale:")
                                        .fontWeight(.medium)
                                    Text("\(String(format: "%.2f", job.scalePixelsPerFoot)) pixels/foot")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .font(.caption)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                        
                        // Image replacement success/error messages
                        if imageReplacementSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Image replaced successfully")
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                            .onAppear {
                                // Auto-dismiss success message after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    imageReplacementSuccess = false
                                }
                            }
                        }
                        
                        if let error = imageReplacementError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    
                    // Property Location Map (constrained so page scroll isn't captured by map gestures)
                    PropertyLocationMap(job: job)
                        .frame(width: 600, height: 440)
                } else if job.status == "failed" {
                    // Error Display
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Scraping Failed")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let errorMessage = job.errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Retry Scraping") {
                            retryScraping()
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if job.status == "running" {
                    // Loading Display
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Scraping in Progress...")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("This may take up to 2 minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Queued Display
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Queued for Scraping")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("This job will be processed when scraping starts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .padding(.trailing, 24)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showingImageEditor) {
            if let imagePath = job.overheadImagePath {
                ImageEditorView(imagePath: imagePath, job: job)
                    .frame(minWidth: 1400, idealWidth: 1600, maxWidth: 1800, minHeight: 800, idealHeight: 1000, maxHeight: 1200)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(job: job)
                .frame(width: 700, height: 700)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNamedStormEdit) {
            NamedStormEditView(job: job)
                .frame(width: 560, height: 760)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.jpeg, .png, .heic, .tiff, .bmp, .gif],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedURL = urls.first {
                    replaceOverheadImage(from: selectedURL)
                }
            case .failure(let error):
                imageReplacementError = "Failed to select image: \(error.localizedDescription)"
                print("MYDEBUG → [JobDetailView] File picker error: \(error.localizedDescription)")
            }
        }
        .onAppear {
            // Initialize zoom and pan from saved values
            zoomScale = CGFloat(job.zoomScale)
            lastZoomScale = zoomScale
            panOffset = .zero
            lastPanOffset = .zero
        }
    }
    
    private func toggleApproval() {
        job.isApproved.toggle()
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save approval status: \(error)")
        }
    }
    
    private func markAsNoData() {
        job.status = "failed"
        job.errorMessage = "No data available - marked by operator"
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to mark as no data: \(error)")
        }
    }
    
    private func retryScraping() {
        job.status = "queued"
        job.errorMessage = nil
        job.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to retry scraping: \(error)")
        }
    }
    
    private func replaceOverheadImage(from sourceURL: URL) {
        print("MYDEBUG → [JobDetailView] Replacing overhead image from: \(sourceURL.path)")
        
        // Clear previous error/success messages
        imageReplacementError = nil
        imageReplacementSuccess = false
        
        // Start accessing security-scoped resource (required for fileImporter URLs)
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Validate that the file is a valid image
        guard let image = NSImage(contentsOf: sourceURL) else {
            imageReplacementError = "Selected file is not a valid image"
            print("MYDEBUG → [JobDetailView] Invalid image file")
            return
        }
        
        // Ensure image can be represented (basic validation)
        guard image.isValid else {
            imageReplacementError = "Selected file is not a valid image format"
            print("MYDEBUG → [JobDetailView] Image validation failed")
            return
        }
        
        // Get the destination path (same location as original)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesPath = documentsPath.appendingPathComponent("Images")
        
        // Create Images directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
            print("MYDEBUG → [JobDetailView] Created Images directory if needed")
        } catch {
            imageReplacementError = "Failed to create Images directory: \(error.localizedDescription)"
            print("MYDEBUG → [JobDetailView] Failed to create directory: \(error)")
            return
        }
        
        // Determine the destination filename (preserve the same naming convention)
        let jobId = job.jobId ?? UUID().uuidString
        let imageFileName = "\(jobId)_overhead.jpg"
        let destinationURL = imagesPath.appendingPathComponent(imageFileName)
        
        // Delete old image if it exists and is different from the new one
        if let oldImagePath = job.overheadImagePath,
           oldImagePath != destinationURL.path,
           FileManager.default.fileExists(atPath: oldImagePath) {
            do {
                try FileManager.default.removeItem(atPath: oldImagePath)
                print("MYDEBUG → [JobDetailView] Deleted old image: \(oldImagePath)")
            } catch {
                print("MYDEBUG → [JobDetailView] Warning: Failed to delete old image: \(error)")
                // Continue anyway - we'll overwrite the new location
            }
        }
        
        // Copy the new image to the destination
        do {
            // If destination already exists, remove it first
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the new image
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("MYDEBUG → [JobDetailView] Successfully copied image to: \(destinationURL.path)")
            
            // Update the job's image path
            job.overheadImagePath = destinationURL.path
            
            // Reset zoom and rotation settings to defaults when replacing image
            job.zoomScale = 1.0
            job.rotation = 0.0
            zoomScale = 1.0
            lastZoomScale = 1.0
            panOffset = .zero
            lastPanOffset = .zero
            
            // Optionally clear source metadata to indicate manual replacement
            // Uncomment if you want to clear source info when manually replacing:
            // job.sourceName = nil
            // job.sourceUrl = nil
            
            job.updatedAt = Date()
            
            // Save the context
            try viewContext.save()
            
            imageReplacementSuccess = true
            print("MYDEBUG → [JobDetailView] Successfully replaced overhead image")
            
        } catch {
            imageReplacementError = "Failed to replace image: \(error.localizedDescription)"
            print("MYDEBUG → [JobDetailView] Failed to replace image: \(error)")
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var statusColor: Color {
        switch status {
        case "queued": return .orange
        case "running": return .blue
        case "completed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.clientName = "Smith"
    job.addressLine1 = "408 2nd Ave NW"
    job.city = "Largo"
    job.state = "FL"
    job.zip = "33770"
    job.status = "completed"
    job.createdAt = Date()
    job.updatedAt = Date()
    
    return JobDetailView(job: job)
        .environment(\.managedObjectContext, context)
}
