//
//  CreateManualJobView.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 11/16/25.
//

import SwiftUI
import CoreData

struct CreateManualJobView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Job fields
    @State private var jobId: String = ""
    @State private var clientName: String = ""
    @State private var addressLine1: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var notes: String = ""
    @State private var phoneNumber: String = ""
    @State private var areasOfConcern: String = ""
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Job Information") {
                    TextField("Job ID (optional)", text: $jobId, prompt: Text("Auto-generated if empty"))
                    
                    TextField("Client Name", text: $clientName)
                    
                    TextField("Address Line 1", text: $addressLine1)
                    
                    HStack {
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                            .frame(width: 80)
                        TextField("ZIP", text: $zip)
                            .frame(width: 100)
                    }
                }
                
                Section("Additional Information") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                    
                    TextField("Phone Number", text: $phoneNumber)
                    
                    TextField("Areas of Concern", text: $areasOfConcern, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job ID: \(jobId.isEmpty ? "Will be auto-generated" : jobId)")
                        Text("Client: \(clientName.isEmpty ? "Not specified" : clientName)")
                        Text("Address: \(formatPreviewAddress())")
                        if !notes.isEmpty {
                            Text("Notes: \(notes)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 600, idealWidth: 700, maxWidth: 800)
            .navigationTitle("Create Job Manually")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createJob()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !clientName.isEmpty && 
        !addressLine1.isEmpty && 
        !city.isEmpty && 
        !state.isEmpty && 
        !zip.isEmpty
    }
    
    private func formatPreviewAddress() -> String {
        var components: [String] = []
        if !addressLine1.isEmpty {
            components.append(addressLine1)
        }
        if !city.isEmpty {
            components.append(city)
        }
        if !state.isEmpty {
            components.append(state)
        }
        if !zip.isEmpty {
            components.append(zip)
        }
        return components.isEmpty ? "Not specified" : components.joined(separator: ", ")
    }
    
    private func createJob() {
        // Generate job ID if not provided
        let finalJobId = jobId.isEmpty ? UUID().uuidString : jobId
        
        // Create new job
        let newJob = Job(context: viewContext)
        newJob.jobId = finalJobId
        newJob.clientName = clientName.isEmpty ? nil : clientName
        newJob.addressLine1 = addressLine1
        newJob.cleanedAddressLine1 = AddressCleaningUtility.cleanAddress(addressLine1)
        newJob.city = city
        newJob.state = state
        newJob.zip = zip.isEmpty ? nil : zip
        newJob.notes = notes.isEmpty ? nil : notes
        newJob.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        newJob.areasOfConcern = areasOfConcern.isEmpty ? nil : areasOfConcern
        newJob.status = "queued"
        newJob.createdAt = Date()
        newJob.updatedAt = Date()
        
        do {
            try viewContext.save()
            print("MYDEBUG → Successfully created manual job: \(finalJobId)")
            alertTitle = "Success"
            alertMessage = "Job '\(finalJobId)' created successfully and added to queue!"
            showingAlert = true
        } catch {
            print("MYDEBUG → Failed to create job: \(error.localizedDescription)")
            alertTitle = "Error"
            alertMessage = "Failed to create job: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    CreateManualJobView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
