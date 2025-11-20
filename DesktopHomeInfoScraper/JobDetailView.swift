//
//  JobDetailView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData

struct JobDetailView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingImageEditor = false
    @State private var scalePixelsPerFoot: Double = 0
    @State private var showingExportOptions = false
    
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
                
                // Main Content
                if job.status == "completed" && job.overheadImagePath != nil {
                    // Image Display
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Property Image")
                            .font(.headline)
                        
                        if let imagePath = job.overheadImagePath,
                           let image = NSImage(contentsOfFile: imagePath) {
                            // Square image container with side cropping
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill) // Force square aspect ratio, crop sides
                                .frame(width: 500, height: 500) // Fixed square container
                                .scaleEffect(CGFloat(job.zoomScale))
                                .rotationEffect(.degrees(job.rotation))
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
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
                                                let newZoom = max(0.5, job.zoomScale - 0.25)
                                                updateImageSettings(zoom: newZoom, rotation: job.rotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 80)
                                            
                                            Button("Zoom In") {
                                                let newZoom = min(2.0, job.zoomScale + 0.25)
                                                updateImageSettings(zoom: newZoom, rotation: job.rotation)
                                            }
                                            .buttonStyle(.bordered)
                                            .frame(minWidth: 80)
                                        }
                                        
                                        Text("Current: \(String(format: "%.1fx", job.zoomScale))")
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
                                if job.zoomScale > 1.8 {
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
                    }
                    
                    // Property Location Map
                    PropertyLocationMap(job: job)
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
                
                // Approval Section
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
                
                Spacer()
                }
                .frame(minWidth: 1200)
                .padding()
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
