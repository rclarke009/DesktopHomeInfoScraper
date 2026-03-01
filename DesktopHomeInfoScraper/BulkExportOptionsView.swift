//
//  BulkExportOptionsView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/28/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import MapKit
import CoreLocation

// Helper function to format address with proper handling of missing components
private func formatAddress(job: Job) -> String {
    var components: [String] = []
    
    // Use original address for display (includes units), cleaned address is only for geocoding
    let addressToUse = job.addressLine1 ?? ""
    if !addressToUse.isEmpty {
        components.append(addressToUse)
    }
    
    if let city = job.city, !city.isEmpty {
        components.append(city)
    }
    
    var cityStateZip: [String] = []
    if let state = job.state, !state.isEmpty {
        cityStateZip.append(state)
    }
    if let zip = job.zip, !zip.isEmpty {
        cityStateZip.append(zip)
    }
    
    if !cityStateZip.isEmpty {
        components.append(cityStateZip.joined(separator: " "))
    }
    
    return components.isEmpty ? "No address" : components.joined(separator: ", ")
}

struct BulkExportOptionsView: View {
    let jobs: [Job]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .jobIntakePackage
    @State private var includeSourceDocs = false
    @State private var deliveryMethod: DeliveryMethod = .sharedFolder
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var exportedPath: String?
    @State private var exportProgress: Double = 0.0
    @State private var currentJobName: String = ""
    @State private var showingFilePicker = false
    
    enum ExportFormat: String, CaseIterable {
        case jobIntakePackage = "Job Intake Package"
        case fieldResultsPackage = "Field Results Package"
        
        var description: String {
            switch self {
            case .jobIntakePackage:
                return "Export all jobs for iPad import (Structure + images)"
            case .fieldResultsPackage:
                return "Export field results (CSV + photos + report)"
            }
        }
    }
    
    enum DeliveryMethod: String, CaseIterable {
        case sharedFolder = "Shared Folder"
        case airdrop = "AirDrop"
        case s3 = "S3 Pre-signed URL"
        
        var description: String {
            switch self {
            case .sharedFolder:
                return "Save to iCloud Drive/Dropbox/OneDrive"
            case .airdrop:
                return "Send directly to iPad via AirDrop"
            case .s3:
                return "Generate download links for iPad app"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Export All Approved Jobs")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Export \(jobs.count) approved jobs for field inspection")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Jobs Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jobs to Export")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Jobs: \(jobs.count)")
                            Text("Jobs with Images: \(jobs.filter { $0.overheadImagePath != nil }.count)")
                            Text("Export Size: ~\(estimatedSizeMB) MB")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        // Job list preview
                        if jobs.count <= 10 {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(jobs.prefix(10), id: \.jobId) { job in
                                    Text("• \(job.jobId ?? "Unknown") - \(job.addressLine1 ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(jobs.prefix(5), id: \.jobId) { job in
                                    Text("• \(job.jobId ?? "Unknown") - \(job.addressLine1 ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("... and \(jobs.count - 5) more jobs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Export Format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Format")
                            .font(.headline)
                        
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            HStack {
                                Button(action: { exportFormat = format }) {
                                    HStack {
                                        Image(systemName: exportFormat == format ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(exportFormat == format ? .blue : .gray)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(format.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text(format.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(exportFormat == format ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(exportFormat == format ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Delivery Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery Method")
                            .font(.headline)
                        
                        ForEach(DeliveryMethod.allCases, id: \.self) { method in
                            HStack {
                                Button(action: { deliveryMethod = method }) {
                                    HStack {
                                        Image(systemName: deliveryMethod == method ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(deliveryMethod == method ? .blue : .gray)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(method.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text(method.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(deliveryMethod == method ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(deliveryMethod == method ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Additional Options
                    if exportFormat == .jobIntakePackage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Options")
                                .font(.headline)
                            
                            HStack {
                                Button(action: { includeSourceDocs.toggle() }) {
                                    HStack {
                                        Image(systemName: includeSourceDocs ? "checkmark.square.fill" : "square")
                                            .foregroundColor(includeSourceDocs ? .blue : .gray)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Include Source Documents")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text("Include raw PDFs and screenshots")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Progress Bar (shown during export)
                    if isExporting {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export Progress")
                                .font(.headline)
                            
                            ProgressView(value: exportProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            if !currentJobName.isEmpty {
                                Text("Processing: \(currentJobName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Error/Success Messages
                    if let error = exportError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if exportSuccess {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Export Successful")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            if let path = exportedPath {
                                Text("Saved to: \(path)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Choose Export Location") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting || jobs.isEmpty)
                    }
                }
                .padding()
            }
        }
        .fileExporter(
            isPresented: $showingFilePicker,
            document: ExportDocument(),
            contentType: .folder,
            defaultFilename: "BulkExport_\(jobs.count)jobs"
        ) { result in
            switch result {
            case .success(let url):
                exportAllJobs(to: url)
            case .failure(let error):
                exportError = "Failed to select location: \(error.localizedDescription)"
            }
        }
    }
    
    private var estimatedSizeMB: Int {
        let jobsWithImages = jobs.filter { $0.overheadImagePath != nil }.count
        let estimatedImageSize = jobsWithImages * 2 // ~2MB per image
        let jsonSize = Double(jobs.count) * 0.01 // ~10KB per job JSON
        return Int((Double(estimatedImageSize) + jsonSize) / 1024.0 / 1024.0)
    }
    
    private func exportAllJobs(to url: URL) {
        isExporting = true
        exportError = nil
        exportSuccess = false
        exportProgress = 0.0
        currentJobName = ""
        
        Task {
            do {
                let exporter = BulkJobExporter()
                let result = try await exporter.exportAllJobs(
                    jobs: jobs,
                    format: exportFormat,
                    includeSourceDocs: includeSourceDocs,
                    deliveryMethod: deliveryMethod,
                    exportURL: url,
                    progressCallback: { progress, currentJob in
                        Task { @MainActor in
                            self.exportProgress = progress
                            self.currentJobName = currentJob
                        }
                    }
                )
                
                await MainActor.run {
                    exportedPath = result.path
                    exportSuccess = true
                    isExporting = false
                    currentJobName = ""
                    
                    // Update all jobs' exportedAt timestamp
                    for job in jobs {
                        job.exportedAt = Date()
                    }
                    try? viewContext.save()
                    
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExporting = false
                    currentJobName = ""
                }
            }
        }
    }
}

// MARK: - Bulk Job Exporter

class BulkJobExporter {
    func exportAllJobs(
        jobs: [Job],
        format: BulkExportOptionsView.ExportFormat,
        includeSourceDocs: Bool,
        deliveryMethod: BulkExportOptionsView.DeliveryMethod,
        exportURL: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> ExportResult {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let packageName: String
        switch format {
        case .jobIntakePackage:
            packageName = "BulkExport-JobIntake-\(jobs.count)jobs-\(timestamp)"
        case .fieldResultsPackage:
            packageName = "BulkExport-FieldReport-\(jobs.count)jobs-\(timestamp)"
        }
        
        let packagePath = exportURL.appendingPathComponent(packageName)
        
        try FileManager.default.createDirectory(at: packagePath, withIntermediateDirectories: true)
        
        switch format {
        case .jobIntakePackage:
            try await exportBulkJobIntakePackage(
                jobs: jobs,
                packagePath: packagePath,
                includeSourceDocs: includeSourceDocs,
                progressCallback: progressCallback
            )
        case .fieldResultsPackage:
            try await exportBulkFieldResultsPackage(
                jobs: jobs,
                packagePath: packagePath,
                progressCallback: progressCallback
            )
        }
        
        return ExportResult(path: packagePath.path)
    }
    
    private func exportBulkJobIntakePackage(
        jobs: [Job],
        packagePath: URL,
        includeSourceDocs: Bool,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws {
        
        // Create jobs.json with all jobs
        let jobData = JobIntakeData(
            version: "1.0",
            createdAt: Date(),
            preparedBy: "DesktopScraper 1.0.0",
            jobs: jobs.map { createJobData(from: $0) }
        )
        
        let jsonData = try JSONEncoder().encode(jobData)
        let jsonURL = packagePath.appendingPathComponent("jobs.json")
        try jsonData.write(to: jsonURL)
        
        progressCallback(0.1, "Created jobs.json")
        
        // Create overhead directory and copy images
        let overheadPath = packagePath.appendingPathComponent("overhead")
        try FileManager.default.createDirectory(at: overheadPath, withIntermediateDirectories: true)
        
        let jobsWithImages = jobs.filter { $0.overheadImagePath != nil }
        
        for (index, job) in jobsWithImages.enumerated() {
            guard let imagePath = job.overheadImagePath else { continue }
            
            let imageURL = URL(fileURLWithPath: imagePath)
            let destinationURL = overheadPath.appendingPathComponent("\(job.jobId ?? "job")-overhead.jpg")
            
            try FileManager.default.copyItem(at: imageURL, to: destinationURL)
            
            let progress = 0.1 + (Double(index + 1) / Double(jobsWithImages.count)) * 0.5
            progressCallback(progress, "Copied image for \(job.jobId ?? "job")")
        }
        
        // Create map directory and export map images
        let mapPath = packagePath.appendingPathComponent("map")
        try FileManager.default.createDirectory(at: mapPath, withIntermediateDirectories: true)
        
        let totalJobs = jobs.count
        for (index, job) in jobs.enumerated() {
            if let mapImage = try await generateMapImage(for: job) {
                let mapImageURL = mapPath.appendingPathComponent("\(job.jobId ?? "job")-location-map.png")
                if let tiffData = mapImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    try pngData.write(to: mapImageURL)
                }
            }
            
            let progress = 0.6 + (Double(index + 1) / Double(totalJobs)) * 0.3
            progressCallback(progress, "Generated map for \(job.jobId ?? "job")")
        }
        
        // Copy custom hurricane / weather images
        let customHurricaneImagesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_hurricane_images")
        let imagesPath = packagePath.appendingPathComponent("images")
        for job in jobs where job.customHurricaneImagePath != nil && !(job.customHurricaneImagePath ?? "").isEmpty {
            guard let customPath = job.customHurricaneImagePath else { continue }
            let sourceImageURL = customHurricaneImagesDir.appendingPathComponent(customPath)
            if FileManager.default.fileExists(atPath: sourceImageURL.path) {
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
                let destFileName = "\(job.jobId ?? "job")_custom_hurricane.jpg"
                let destURL = imagesPath.appendingPathComponent(destFileName)
                try FileManager.default.copyItem(at: sourceImageURL, to: destURL)
            }
        }
        
        // Create source_docs directory if requested
        if includeSourceDocs {
            let sourceDocsPath = packagePath.appendingPathComponent("source_docs")
            try FileManager.default.createDirectory(at: sourceDocsPath, withIntermediateDirectories: true)
            
            // In a real implementation, you would copy the source PDFs/screenshots here
        }
        
        progressCallback(1.0, "Export completed")
    }
    
    private func exportBulkFieldResultsPackage(
        jobs: [Job],
        packagePath: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws {
        // This would export the field results from the iPad app
        // For now, we'll create a placeholder structure
        
        for (index, job) in jobs.enumerated() {
            let jobData = FieldResultsData(
                intake: IntakeData(
                    sourceName: job.sourceName,
                    sourceUrl: job.sourceUrl,
                    fetchedAt: job.updatedAt
                ),
                field: FieldData(
                    inspector: "Field Inspector",
                    date: Date(),
                    overheadFile: "overhead_with_dots.png",
                    windows: []
                )
            )
            
            let jsonData = try JSONEncoder().encode(jobData)
            let jsonURL = packagePath.appendingPathComponent("\(job.jobId ?? "job").json")
            try jsonData.write(to: jsonURL)
            
            let progress = Double(index + 1) / Double(jobs.count)
            progressCallback(progress, "Processed \(job.jobId ?? "job")")
        }
    }
    
    private func createJobData(from job: Job) -> ExportJobData {
        let jobId = job.jobId ?? "job"
        let customHurricaneFile: String? = (job.customHurricaneImagePath != nil && !(job.customHurricaneImagePath ?? "").isEmpty)
            ? "images/\(jobId)_custom_hurricane.jpg"
            : nil
        return ExportJobData(
            jobId: job.jobId ?? UUID().uuidString,
            clientName: job.clientName,
            address: AddressData(
                line1: job.addressLine1 ?? "",
                city: job.city ?? "",
                state: job.state ?? "",
                zip: job.zip
            ),
            notes: job.notes,
            phoneNumber: job.phoneNumber,
            areasOfConcern: job.areasOfConcern,
            overhead: OverheadData(
                imageFile: job.overheadImagePath != nil ? "overhead/\(jobId)-overhead.jpg" : nil,
                source: SourceData(
                    name: job.sourceName,
                    url: job.sourceUrl,
                    fetchedAt: job.updatedAt
                ),
                scalePixelsPerFoot: job.scalePixelsPerFoot > 0 ? job.scalePixelsPerFoot : nil,
                zoomScale: job.zoomScale > 1.0 ? job.zoomScale : nil,
                rotation: job.rotation != 0.0 ? job.rotation : nil
            ),
            namedStormName: job.namedStormName,
            namedStormDate: job.namedStormDate,
            namedStormWeatherSource: job.namedStormWeatherSource,
            customWeatherText: job.customWeatherText,
            customHurricaneImageFile: customHurricaneFile
        )
    }
    
    private func generateMapImage(for job: Job) async throws -> NSImage? {
        // Use formatAddress helper which handles cleaned address and proper formatting
        let addressString = formatAddress(job: job)
        
        return try await withCheckedThrowingContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(addressString) { placemarks, error in
                if let error = error {
                    print("⚠️ [BulkJobExporter] Geocoding failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    print("⚠️ [BulkJobExporter] No location found for address: \(addressString)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let coordinate = location.coordinate
                
                // Florida approximate bounds for map region
                let floridaCenter = CLLocationCoordinate2D(latitude: 28.5, longitude: -82.0)
                let floridaSpan = MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 8.0)
                let region = MKCoordinateRegion(center: floridaCenter, span: floridaSpan)
                
                // Use MKMapSnapshotter for image export
                let options = MKMapSnapshotter.Options()
                options.region = region
                options.size = NSSize(width: 800, height: 600)
                options.mapType = .standard
                
                let snapshotter = MKMapSnapshotter(options: options)
                snapshotter.start { snapshot, error in
                    guard let snapshot = snapshot else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let image = snapshot.image
                    
                    // Draw annotation on the image
                    let finalImage = NSImage(size: image.size)
                    finalImage.lockFocus()
                    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
                    
                    // Calculate annotation position
                    let point = snapshot.point(for: coordinate)
                    let annotationSize: CGFloat = 20
                    let annotationRect = NSRect(
                        x: point.x - annotationSize / 2,
                        y: point.y - annotationSize / 2,
                        width: annotationSize,
                        height: annotationSize
                    )
                    
                    // Draw red pin
                    NSColor.red.setFill()
                    let path = NSBezierPath(ovalIn: annotationRect)
                    path.fill()
                    
                    // Draw white border
                    NSColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                    
                    finalImage.unlockFocus()
                    continuation.resume(returning: finalImage)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let jobs = (0..<5).map { i in
        let job = Job(context: context)
        job.jobId = "E2025-0509\(i)"
        job.clientName = "Client \(i)"
        job.addressLine1 = "\(100 + i) Main St"
        job.city = "Tampa"
        job.state = "FL"
        job.zip = "33601"
        job.isApproved = true
        job.status = "completed"
        return job
    }
    
    return BulkExportOptionsView(jobs: jobs)
        .environment(\.managedObjectContext, context)
}
