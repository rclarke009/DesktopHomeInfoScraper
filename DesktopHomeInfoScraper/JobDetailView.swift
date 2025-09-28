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
    
    var body: some View {
        NavigationView {
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
                        Button("Edit Image") {
                            showingImageEditor = true
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    
                    if job.isApproved {
                        Button("Export Job Package") {
                            showingExportOptions = true
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                    }
                }
                
                // Main Content
                if job.status == "completed" && job.overheadImagePath != nil {
                    // Image Display
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Property Image")
                            .font(.headline)
                        
                        if let imagePath = job.overheadImagePath,
                           let image = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
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
            .padding()
            .frame(width: 600, height: 700)
        }
        .sheet(isPresented: $showingImageEditor) {
            if let imagePath = job.overheadImagePath {
                ImageEditorView(imagePath: imagePath, job: job)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(job: job)
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
