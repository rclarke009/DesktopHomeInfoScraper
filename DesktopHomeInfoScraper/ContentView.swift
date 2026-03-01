//
//  ContentView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

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

/// Used to report host window size so sheets can size to fit (e.g. Edit Job).
private struct HostWindowSizeKey: PreferenceKey {
    static var defaultValue: CGSize { CGSize(width: 900, height: 700) }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var scrapingManager = ScrapingManager()
    @State private var showingCSVImport = false
    @State private var showingManualJobCreation = false
    @State private var selectedJob: Job?
    @State private var showingJobDetail = false
    @State private var showingSettings = false
    @State private var refreshTrigger = false
    @State private var showingDeleteAllConfirmation = false
    @State private var jobToDelete: Job?
    @State private var showingDeleteJobConfirmation = false
    @State private var showingBulkExportOptions = false
    @State private var showImages = true
    @State private var showingStormCatalog = false
    /// Host window size so Edit Job sheet can fit on screen (updated via preference).
    @State private var hostWindowSize: CGSize = CGSize(width: 900, height: 700)

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Job.createdAt, ascending: false)],
        animation: .default)
    private var jobs: FetchedResults<Job>

    var body: some View {
        NavigationView {
            // Sidebar (scrollable so Start Scraping / Settings are reachable when window is short)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Property Scraper")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Google Maps Aerial Scraper")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Import Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Jobs")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: { showingCSVImport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import CSV File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    Button(action: { showingManualJobCreation = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Job Manually")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    // Debug: Reset job statuses
                    Button(action: { 
                        print("🔄 [ContentView] Resetting all job statuses to 'queued'")
                        for job in jobs {
                            job.status = "queued"
                            job.updatedAt = Date()
                        }
                        try? viewContext.save()
                        refreshTrigger.toggle()
                        print("🔄 [ContentView] Reset complete. Jobs count: \(jobs.count)")
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset Jobs to Queued")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    // Debug: Force refresh
                    Button(action: { 
                        print("🔄 [ContentView] Forcing UI refresh")
                        refreshTrigger.toggle()
                        print("🔄 [ContentView] Refresh trigger toggled to: \(refreshTrigger)")
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Force Refresh UI")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    // Delete All Jobs Button
                    Button(action: { 
                        showingDeleteAllConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete All Jobs")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Export Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Jobs")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: { 
                        showingBulkExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Approved Jobs")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .disabled({
                        let approvedJobs = jobs.filter { $0.isApproved && $0.status == "completed" }
                        return approvedJobs.isEmpty
                    }())
                }

                Divider()

                // Storm Catalog Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Storm Catalog")
                        .font(.headline)
                        .padding(.horizontal)

                    Button(action: { showingStormCatalog = true }) {
                        HStack {
                            Image(systemName: "hurricane")
                            Text("Manage storms")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }

                Divider()

                // Display Options Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Options")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Toggle("Show Images", isOn: $showImages)
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.horizontal)
                }
                
                Divider()
                
                // Job Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Job Status")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        StatusRow(status: "Queued", count: jobs.filter { $0.status == "queued" }.count, color: .orange)
                        StatusRow(status: "Running", count: jobs.filter { $0.status == "running" }.count, color: .blue)
                        StatusRow(status: "Completed", count: jobs.filter { $0.status == "completed" }.count, color: .green)
                        StatusRow(status: "Failed", count: jobs.filter { $0.status == "failed" }.count, color: .red)
                        StatusRow(status: "Approved", count: jobs.filter { $0.isApproved }.count, color: .purple)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Scraping Controls
                VStack(spacing: 8) {
                    if scrapingManager.isRunning {
                        Button(action: { scrapingManager.stopScraping() }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Stop Scraping")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: { 
                            print("🔘 [ContentView] Start Scraping button pressed")
                            print("🔘 [ContentView] Current jobs count: \(jobs.count)")
                            print("🔘 [ContentView] ScrapingManager isRunning: \(scrapingManager.isRunning)")
                            scrapingManager.startScraping(context: viewContext) 
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Start Scraping")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled({
                            let queuedJobs = jobs.filter { $0.status == "queued" }
                            print("🔘 [ContentView] Queued jobs count: \(queuedJobs.count), Total jobs: \(jobs.count)")
                            print("🔘 [ContentView] Job statuses: \(jobs.map { $0.status ?? "nil" })")
                            print("🔘 [ContentView] Refresh trigger: \(refreshTrigger)")
                            return queuedJobs.isEmpty
                        }())
                    }
                }
                .padding(.horizontal)
                
                // Settings Button
                Button(action: { showingSettings = true }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 250)
            
            // Main Content
            VStack {
                if jobs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "building.2")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Jobs Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Import a CSV file to get started with property scraping")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Import CSV File") {
                            showingCSVImport = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Jobs List
                    List(jobs, selection: $selectedJob) { job in
                        JobRowView(job: job, showImage: showImages, onDelete: { deleteJob($0) })
                            .onTapGesture {
                                selectedJob = job
                                showingJobDetail = true
                            }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .background(
            GeometryReader { g in
                Color.clear.preference(key: HostWindowSizeKey.self, value: g.size)
            }
        )
        .onPreferenceChange(HostWindowSizeKey.self) { hostWindowSize = $0 }
        .sheet(isPresented: $showingCSVImport) {
            CSVImportView()
                .frame(width: 800, height: 700)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingManualJobCreation) {
            CreateManualJobView()
                .frame(width: 700, height: 520)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingJobDetail) {
            if let job = selectedJob {
                JobDetailView(job: job)
                    .frame(
                        width: min(900, hostWindowSize.width * 0.9),
                        height: min(640, hostWindowSize.height * 0.85)
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStormCatalog) {
            StormCatalogListView()
                .frame(width: 640, height: 480)
                .presentationDetents([.large])
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingBulkExportOptions) {
            BulkExportOptionsView(jobs: Array(jobs.filter { $0.isApproved && $0.status == "completed" }))
                .frame(width: 800, height: 700)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete All Jobs", isPresented: $showingDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllJobs()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete all \(jobs.count) jobs? This action cannot be undone.")
        }
    }
    
    // MARK: - Delete Functions
    
    private func deleteJob(_ job: Job) {
        print("🗑️ [ContentView] Deleting job: \(job.jobId ?? "Unknown")")
        
        // Delete associated image file if it exists
        if let imagePath = job.overheadImagePath {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: imagePath) {
                do {
                    try fileManager.removeItem(atPath: imagePath)
                    print("🗑️ [ContentView] Deleted image file: \(imagePath)")
                } catch {
                    print("⚠️ [ContentView] Failed to delete image file: \(error)")
                }
            }
        }
        
        // Delete the job from Core Data
        viewContext.delete(job)
        
        do {
            try viewContext.save()
            print("✅ [ContentView] Successfully deleted job: \(job.jobId ?? "Unknown")")
            refreshTrigger.toggle()
        } catch {
            print("❌ [ContentView] Failed to delete job: \(error)")
        }
    }
    
    private func deleteAllJobs() {
        print("🗑️ [ContentView] Deleting all \(jobs.count) jobs")
        
        // Delete associated image files
        for job in jobs {
            if let imagePath = job.overheadImagePath {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: imagePath) {
                    do {
                        try fileManager.removeItem(atPath: imagePath)
                        print("🗑️ [ContentView] Deleted image file: \(imagePath)")
                    } catch {
                        print("⚠️ [ContentView] Failed to delete image file: \(error)")
                    }
                }
            }
        }
        
        // Delete all jobs from Core Data
        for job in jobs {
            viewContext.delete(job)
        }
        
        do {
            try viewContext.save()
            print("✅ [ContentView] Successfully deleted all \(jobs.count) jobs")
            refreshTrigger.toggle()
        } catch {
            print("❌ [ContentView] Failed to delete all jobs: \(error)")
        }
    }
}

struct StatusRow: View {
    let status: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(status)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct JobRowView: View {
    let job: Job
    let showImage: Bool
    let onDelete: (Job) -> Void
    @State private var showingDeleteConfirmation = false
    
    var statusColor: Color {
        switch job.status {
        case "queued": return .orange
        case "running": return .blue
        case "completed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Image thumbnail (if enabled and available)
            if showImage && job.status == "completed", let imagePath = job.overheadImagePath {
                AsyncImage(url: URL(fileURLWithPath: imagePath)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill) // Force square aspect ratio, crop sides
                        .frame(width: 60, height: 60)
                        .scaleEffect(CGFloat(job.zoomScale)) // Apply saved zoom
                        .rotationEffect(.degrees(job.rotation)) // Apply saved rotation
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
            } else if showImage {
                // Placeholder for jobs without images
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: job.status == "completed" ? "photo.badge.exclamationmark" : "photo")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            }
            
            // Job details
            VStack(alignment: .leading, spacing: 4) {
                Text(job.jobId ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(formatAddress(job: job))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let clientName = job.clientName {
                    Text("Client: \(clientName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(job.status?.capitalized ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if job.isApproved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Text(job.createdAt ?? Date(), formatter: dateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Delete button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Delete Job", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete(job)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete job \(job.jobId ?? "Unknown")? This action cannot be undone.")
            }
        }
        .padding(.vertical, 4)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
