//
//  AppSettings.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import SwiftUI
import AppKit

class AppSettings: ObservableObject {
    @Published var scrapingDelay: Double = 2.0
    @Published var maxRetries: Int = 3
    @Published var exportPath: String = ""
    @Published var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    @Published var enableFallbackScrapers: Bool = true
    @Published var autoApproveOnSuccess: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        scrapingDelay = userDefaults.double(forKey: "scrapingDelay")
        if scrapingDelay == 0 { scrapingDelay = 2.0 }
        
        maxRetries = userDefaults.integer(forKey: "maxRetries")
        if maxRetries == 0 { maxRetries = 3 }
        
        exportPath = userDefaults.string(forKey: "exportPath") ?? ""
        
        userAgent = userDefaults.string(forKey: "userAgent") ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        enableFallbackScrapers = userDefaults.bool(forKey: "enableFallbackScrapers")
        autoApproveOnSuccess = userDefaults.bool(forKey: "autoApproveOnSuccess")
    }
    
    func saveSettings() {
        userDefaults.set(scrapingDelay, forKey: "scrapingDelay")
        userDefaults.set(maxRetries, forKey: "maxRetries")
        userDefaults.set(exportPath, forKey: "exportPath")
        userDefaults.set(userAgent, forKey: "userAgent")
        userDefaults.set(enableFallbackScrapers, forKey: "enableFallbackScrapers")
        userDefaults.set(autoApproveOnSuccess, forKey: "autoApproveOnSuccess")
    }
    
    func selectExportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select export folder for job packages"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                exportPath = url.path
            }
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Scraping Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delay between requests (seconds)")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: $settings.scrapingDelay, in: 1...10, step: 0.5)
                            Text("\(String(format: "%.1f", settings.scrapingDelay))s")
                                .frame(width: 40)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum retries per job")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(settings.maxRetries) },
                                set: { settings.maxRetries = Int($0) }
                            ), in: 1...5, step: 1)
                            Text("\(settings.maxRetries)")
                                .frame(width: 20)
                        }
                    }
                    
                    Toggle("Enable fallback scrapers", isOn: $settings.enableFallbackScrapers)
                    Toggle("Auto-approve successful scrapes", isOn: $settings.autoApproveOnSuccess)
                }
                
                Section("Export Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default export path")
                            .font(.headline)
                        
                        HStack {
                            TextField("Export path", text: $settings.exportPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Browse") {
                                settings.selectExportFolder()
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }
                
                Section("Advanced") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Agent String")
                            .font(.headline)
                        
                        TextField("User agent", text: $settings.userAgent, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3)
                    }
                }
            }
            .padding()
            .frame(width: 500, height: 400)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.saveSettings()
                        dismiss()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
