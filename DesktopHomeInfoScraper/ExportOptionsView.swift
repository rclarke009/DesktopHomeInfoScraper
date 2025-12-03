//
//  ExportOptionsView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import MapKit
import CoreLocation

// Helper function to format address with proper handling of missing components
private func formatAddress(job: Job) -> String {
    var components: [String] = []
    
    // Use cleaned address if available, fallback to original
    let addressToUse = job.cleanedAddressLine1 ?? job.addressLine1 ?? ""
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

struct ExportOptionsView: View {
    let job: Job
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .jobIntakePackage
    @State private var includeSourceDocs = false
    @State private var deliveryMethod: DeliveryMethod = .sharedFolder
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var exportedPath: String?
    @State private var showingFilePicker = false
    
    enum ExportFormat: String, CaseIterable {
        case jobIntakePackage = "Job Intake Package"
        case fieldResultsPackage = "Field Results Package"
        
        var description: String {
            switch self {
            case .jobIntakePackage:
                return "Export for iPad import (JSON + images)"
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
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Export Job Package")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose export format and delivery method")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Job Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Job Details")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Job ID: \(job.jobId ?? "Unknown")")
                        Text(formatAddress(job: job))
                        if let clientName = job.clientName {
                            Text("Client: \(clientName)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .disabled(isExporting)
                }
                }
                .padding()
            }
        }
        .fileExporter(
            isPresented: $showingFilePicker,
            document: ExportDocument(),
            contentType: .folder,
            defaultFilename: "\(job.jobId ?? "Job")_Export"
        ) { result in
            switch result {
            case .success(let url):
                exportJob(to: url)
            case .failure(let error):
                exportError = "Failed to select location: \(error.localizedDescription)"
            }
        }
    }
    
    private func exportJob(to url: URL) {
        isExporting = true
        exportError = nil
        exportSuccess = false
        
        Task {
            do {
                let exporter = JobExporter()
                let result = try await exporter.exportJob(
                    job: job,
                    format: exportFormat,
                    includeSourceDocs: includeSourceDocs,
                    deliveryMethod: deliveryMethod,
                    exportURL: url
                )
                
                await MainActor.run {
                    exportedPath = result.path
                    exportSuccess = true
                    isExporting = false
                    
                    // Update job status
                    job.exportedAt = Date()
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
                }
            }
        }
    }
}

// MARK: - Job Exporter

class JobExporter {
    func exportJob(
        job: Job,
        format: ExportOptionsView.ExportFormat,
        includeSourceDocs: Bool,
        deliveryMethod: ExportOptionsView.DeliveryMethod,
        exportURL: URL
    ) async throws -> ExportResult {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let packageName: String
        switch format {
        case .jobIntakePackage:
            packageName = "\(job.jobId ?? "Job")_JobIntake_\(timestamp)"
        case .fieldResultsPackage:
            packageName = "\(job.jobId ?? "Job")_FieldReport_\(timestamp)"
        }
        
        let packagePath = exportURL.appendingPathComponent(packageName)
        
        try FileManager.default.createDirectory(at: packagePath, withIntermediateDirectories: true)
        
        switch format {
        case .jobIntakePackage:
            try await exportJobIntakePackage(job: job, packagePath: packagePath, includeSourceDocs: includeSourceDocs)
        case .fieldResultsPackage:
            try await exportFieldResultsPackage(job: job, packagePath: packagePath)
        }
        
        return ExportResult(path: packagePath.path)
    }
    
    private func exportJobIntakePackage(job: Job, packagePath: URL, includeSourceDocs: Bool) async throws {
        // Create jobs.json
        let jobData = JobIntakeData(
            version: "1.0",
            createdAt: Date(),
            preparedBy: "DesktopScraper 1.0.0",
            jobs: [createJobData(from: job)]
        )
        
        let jsonData = try JSONEncoder().encode(jobData)
        let jsonURL = packagePath.appendingPathComponent("jobs.json")
        try jsonData.write(to: jsonURL)
        
        // Create overhead directory and copy image
        let overheadPath = packagePath.appendingPathComponent("overhead")
        try FileManager.default.createDirectory(at: overheadPath, withIntermediateDirectories: true)
        
        if let imagePath = job.overheadImagePath {
            let imageURL = URL(fileURLWithPath: imagePath)
            let destinationURL = overheadPath.appendingPathComponent("\(job.jobId ?? "job")_overhead.jpg")
            try FileManager.default.copyItem(at: imageURL, to: destinationURL)
        }
        
        // Create map directory and export map image
        let mapPath = packagePath.appendingPathComponent("map")
        try FileManager.default.createDirectory(at: mapPath, withIntermediateDirectories: true)
        
        if let mapImage = try await generateMapImage(for: job) {
            let mapImageURL = mapPath.appendingPathComponent("\(job.jobId ?? "job")_location_map.png")
            if let tiffData = mapImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try pngData.write(to: mapImageURL)
            }
        }
        
        // Create source_docs directory if requested
        if includeSourceDocs {
            let sourceDocsPath = packagePath.appendingPathComponent("source_docs")
            try FileManager.default.createDirectory(at: sourceDocsPath, withIntermediateDirectories: true)
            
            // In a real implementation, you would copy the source PDFs/screenshots here
        }
    }
    
    private func generateMapImage(for job: Job) async throws -> NSImage? {
        // Use formatAddress helper which handles cleaned address and proper formatting
        let addressString = formatAddress(job: job)
        
        return try await withCheckedThrowingContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(addressString) { placemarks, error in
                if let error = error {
                    print("⚠️ [JobExporter] Geocoding failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    print("⚠️ [JobExporter] No location found for address: \(addressString)")
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
    
    private func exportFieldResultsPackage(job: Job, packagePath: URL) async throws {
        // This would export the field results from the iPad app
        // For now, we'll create a placeholder structure
        
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
        let jsonURL = packagePath.appendingPathComponent("job.json")
        try jsonData.write(to: jsonURL)
        
        // Create other required files (windows.csv, photos/, report/)
        // This would be populated by the iPad app
    }
    
    private func createJobData(from job: Job) -> ExportJobData {
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
                imageFile: job.overheadImagePath != nil ? "overhead/\(job.jobId ?? "job")_overhead.jpg" : nil,
                source: SourceData(
                    name: job.sourceName,
                    url: job.sourceUrl,
                    fetchedAt: job.updatedAt
                ),
                scalePixelsPerFoot: job.scalePixelsPerFoot > 0 ? job.scalePixelsPerFoot : nil,
                zoomScale: job.zoomScale > 1.0 ? job.zoomScale : nil,
                rotation: job.rotation != 0.0 ? job.rotation : nil
            )
        )
    }
}

// MARK: - Data Models

struct ExportResult {
    let path: String
}

// Document class for file picker
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    init() {}
    
    init(configuration: ReadConfiguration) throws {
        // Not needed for our use case
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(directoryWithFileWrappers: [:])
    }
}

struct JobIntakeData: Codable {
    let version: String
    let createdAt: Date
    let preparedBy: String
    let jobs: [ExportJobData]
}

struct ExportJobData: Codable {
    let jobId: String
    let clientName: String?
    let address: AddressData
    let notes: String?
    let phoneNumber: String?
    let areasOfConcern: String?
    let overhead: OverheadData
}

struct AddressData: Codable {
    let line1: String
    let city: String
    let state: String
    let zip: String?
}

struct OverheadData: Codable {
    let imageFile: String?
    let source: SourceData
    let scalePixelsPerFoot: Double?
    let zoomScale: Double?
    let rotation: Double?
}

struct SourceData: Codable {
    let name: String?
    let url: String?
    let fetchedAt: Date?
}

struct FieldResultsData: Codable {
    let intake: IntakeData
    let field: FieldData
}

struct IntakeData: Codable {
    let sourceName: String?
    let sourceUrl: String?
    let fetchedAt: Date?
}

struct FieldData: Codable {
    let inspector: String
    let date: Date
    let overheadFile: String
    let windows: [WindowData]
}

struct WindowData: Codable {
    // Placeholder for window data from iPad app
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
    job.isApproved = true
    
    return ExportOptionsView(job: job)
        .environment(\.managedObjectContext, context)
}
