//
//  CSVImportView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct CSVImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: URL?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess = false
    @State private var importedCount = 0
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Import Jobs from CSV")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select a CSV file with job addresses to scrape property data")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // File Selection
                VStack(spacing: 16) {
                    if let selectedFile = selectedFile {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                
                                Text(selectedFile.lastPathComponent)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Remove") {
                                    self.selectedFile = nil
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            
                            Text("Ready to import")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Button(action: { showingFilePicker = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                                
                                Text("Select CSV File")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text("Click to browse for your CSV file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // CSV Format Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Expected CSV Format")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Required columns:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• JobID (optional)")
                            Text("• Client")
                            Text("• AddressLine1")
                            Text("• City")
                            Text("• State")
                            Text("• Zip")
                            Text("• Notes (optional)")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    }
                    
                    Text("Example: E2025-05091, Smith, 408 2nd Ave NW, Largo, FL, 33770, Rush")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(20)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // Error/Success Messages
                if let error = importError {
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
                
                if importSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Successfully imported \(importedCount) jobs")
                            .font(.caption)
                            .foregroundColor(.green)
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
                    .font(.headline)
                    .buttonStyle(BorderedButtonStyle())
                    
                    Button("Import Jobs") {
                        importJobs()
                    }
                    .font(.headline)
                    .buttonStyle(BorderedProminentButtonStyle())
                    .disabled(selectedFile == nil || isImporting)
                }
            }
            .padding()
            .frame(minWidth: 600, idealWidth: 700, maxWidth: 800, minHeight: 500, idealHeight: 600, maxHeight: 700)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFile = urls.first
                importError = nil
            case .failure(let error):
                importError = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
    
    private func selectFile() {
        // This will be handled by the fileImporter
    }
    
    private func importJobs() {
        guard let fileURL = selectedFile else { return }
        
        isImporting = true
        importError = nil
        importSuccess = false
        
        Task {
            do {
                let data = try Data(contentsOf: fileURL)
                let content = String(data: data, encoding: .utf8) ?? ""
                
                let jobs = try parseCSV(content: content)
                
                await MainActor.run {
                    // Save jobs to Core Data
                    for jobData in jobs {
                        let job = Job(context: viewContext)
                        job.jobId = jobData.jobId ?? UUID().uuidString
                        job.clientName = jobData.clientName
                        job.addressLine1 = jobData.addressLine1
                        job.city = jobData.city
                        job.state = jobData.state
                        job.zip = jobData.zip
                        job.notes = jobData.notes
                        job.status = "queued"
                        job.createdAt = Date()
                        job.updatedAt = Date()
                    }
                    
                    do {
                        try viewContext.save()
                        importedCount = jobs.count
                        importSuccess = true
                        isImporting = false
                        
                        // Auto-dismiss after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    } catch {
                        importError = "Failed to save jobs: \(error.localizedDescription)"
                        isImporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    importError = "Failed to read file: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
    
    private func parseCSV(content: String) throws -> [CSVJobData] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.invalidFormat("CSV file must have at least a header row and one data row")
        }
        
        let header = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Find column indices
        let jobIdIndex = header.firstIndex(of: "JobID") ?? header.firstIndex(of: "jobid") ?? header.firstIndex(of: "job_id")
        let clientIndex = header.firstIndex(of: "Client") ?? header.firstIndex(of: "client")
        let addressIndex = header.firstIndex(of: "AddressLine1") ?? header.firstIndex(of: "addressline1") ?? header.firstIndex(of: "address")
        let cityIndex = header.firstIndex(of: "City") ?? header.firstIndex(of: "city")
        let stateIndex = header.firstIndex(of: "State") ?? header.firstIndex(of: "state")
        let zipIndex = header.firstIndex(of: "Zip") ?? header.firstIndex(of: "zip")
        let notesIndex = header.firstIndex(of: "Notes") ?? header.firstIndex(of: "notes")
        
        guard let client = clientIndex,
              let address = addressIndex,
              let city = cityIndex,
              let state = stateIndex else {
            throw ImportError.missingRequiredColumns("Missing required columns: Client, AddressLine1, City, State")
        }
        
        var jobs: [CSVJobData] = []
        
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard columns.count > max(client, address, city, state) else {
                continue // Skip malformed rows
            }
            
            let job = CSVJobData(
                jobId: jobIdIndex.map { columns.indices.contains($0) ? columns[$0] : nil } ?? nil,
                clientName: columns[client],
                addressLine1: columns[address],
                city: columns[city],
                state: columns[state],
                zip: zipIndex.map { columns.indices.contains($0) ? columns[$0] : nil } ?? nil,
                notes: notesIndex.map { columns.indices.contains($0) ? columns[$0] : nil } ?? nil
            )
            
            jobs.append(job)
        }
        
        return jobs
    }
}

struct CSVJobData {
    let jobId: String?
    let clientName: String
    let addressLine1: String
    let city: String
    let state: String
    let zip: String?
    let notes: String?
}

enum ImportError: LocalizedError {
    case invalidFormat(String)
    case missingRequiredColumns(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return message
        case .missingRequiredColumns(let message):
            return message
        }
    }
}

#Preview {
    CSVImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
