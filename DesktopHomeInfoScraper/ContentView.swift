//
//  ContentView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var scrapingManager = ScrapingManager()
    @State private var showingCSVImport = false
    @State private var selectedJob: Job?
    @State private var showingJobDetail = false
    @State private var showingSettings = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Job.createdAt, ascending: false)],
        animation: .default)
    private var jobs: FetchedResults<Job>

    var body: some View {
        NavigationView {
            // Sidebar
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Property Scraper")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Hillsborough County & FL Property Data")
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
                        Button(action: { scrapingManager.startScraping(context: viewContext) }) {
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
                        .disabled(jobs.filter { $0.status == "queued" }.isEmpty)
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
                        JobRowView(job: job)
                            .onTapGesture {
                                selectedJob = job
                                showingJobDetail = true
                            }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .sheet(isPresented: $showingCSVImport) {
            CSVImportView()
        }
        .sheet(isPresented: $showingJobDetail) {
            if let job = selectedJob {
                JobDetailView(job: job)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.jobId ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(job.addressLine1 ?? ""), \(job.city ?? ""), \(job.state ?? "")")
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
