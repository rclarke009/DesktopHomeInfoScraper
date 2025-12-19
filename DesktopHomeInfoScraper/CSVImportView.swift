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
            ScrollView {
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
                        Text("New Format (with filtering):")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Name, Inspection Date, Window Test Status, Roof Report Status")
                            Text("• Areas of concern for mold, Tenant name, Tenants Phone")
                            Text("• additional tenant, Insured's Address, Email, Priority")
                            Text("• Only rows with 'Needs window Test' status will be imported")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                        
                        Text("Legacy Format (still supported):")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• JobID (optional), Client, AddressLine1, City, State, Zip, Notes (optional)")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    }
                    
                    Text("The app will automatically detect which format you're using based on the column headers.")
                        .font(.caption)
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
                .padding()
                }
            }
            .frame(minWidth: 600, idealWidth: 800, maxWidth: 1000)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .frame(minHeight: 600, idealHeight: 700, maxHeight: 900)
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
                // Start accessing the security-scoped resource
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                let data = try Data(contentsOf: fileURL)
                let content = String(data: data, encoding: .utf8) ?? ""
                
                let jobs = try parseCSV(content: content)
                
                await MainActor.run {
                    // Save jobs to Core Data
                    for jobData in jobs {
                        let job = Job(context: viewContext)
                        job.jobId = jobData.jobId ?? UUID().uuidString
                        // Use name field if available, otherwise use clientName
                        job.clientName = jobData.name ?? jobData.clientName
                        // Store original address in addressLine1
                        job.addressLine1 = jobData.addressLine1
                        // Clean address and store in cleanedAddressLine1
                        job.cleanedAddressLine1 = AddressCleaningUtility.cleanAddress(jobData.addressLine1)
                        job.city = jobData.city
                        job.state = jobData.state
                        job.zip = jobData.zip
                        job.notes = jobData.notes
                        job.phoneNumber = jobData.tenantPhone
                        job.areasOfConcern = jobData.moldConcerns
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
                    importError = "Failed to read file: \(error.localizedDescription). Please ensure you have permission to access this file."
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
        
        // Find the actual header row (look for "Name" or "Insured's Address" column)
        var headerRowIndex: Int?
        var delimiter: String = ","
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            // Check if this line contains header keywords
            if trimmedLine.contains("Insured's Address") || 
               (trimmedLine.contains("Name") && trimmedLine.contains("Window Test Status")) {
                // Determine delimiter
                delimiter = trimmedLine.contains("\t") ? "\t" : ","
                headerRowIndex = index
                break
            }
        }
        
        guard let headerIndex = headerRowIndex else {
            throw ImportError.invalidFormat("Could not find header row with expected columns")
        }
        
        // Parse header with proper CSV parsing
        let headerLine = lines[headerIndex]
        let header = parseCSVLine(headerLine, delimiter: delimiter)
        
        // Find column indices - case-insensitive matching with variations
        let nameIndex = findColumnIndex(in: header, possibleNames: ["Name", "name"])
        let insuredNameIndex = findColumnIndex(in: header, possibleNames: ["Insured's name", "insured's name", "Insureds name", "insureds name", "Insured Name", "insured name", "InsuredName", "insuredname"])
        let inspectionDateIndex = findColumnIndex(in: header, possibleNames: ["Inspection Date", "inspection date", "InspectionDate", "inspectiondate"])
        let windowTestStatusIndex = findColumnIndex(in: header, possibleNames: ["Window Test Status", "window test status", "WindowTestStatus", "windowteststatus"])
        let roofReportStatusIndex = findColumnIndex(in: header, possibleNames: ["Roof Report Status", "roof report status", "RoofReportStatus", "roofreportstatus"])
        let moldConcernsIndex = findColumnIndex(in: header, possibleNames: ["Areas of concern for mold", "areas of concern for mold", "Mold Concerns", "mold concerns"])
        let tenantNameIndex = findColumnIndex(in: header, possibleNames: ["Tenant name", "tenant name", "TenantName", "tenantname", "Tenant Name"])
        let tenantPhoneIndex = findColumnIndex(in: header, possibleNames: ["Tenants Phone", "tenants phone", "TenantsPhone", "tenantsphone", "Tenant Phone"])
        let additionalTenantIndex = findColumnIndex(in: header, possibleNames: ["additional tenant", "Additional Tenant", "AdditionalTenant", "additionaltenant"])
        let insuredAddressIndex = findColumnIndex(in: header, possibleNames: ["Insured's Address", "insured's address", "Insureds Address", "insureds address", "InsuredAddress"])
        let emailIndex = findColumnIndex(in: header, possibleNames: ["Email", "email"])
        let priorityIndex = findColumnIndex(in: header, possibleNames: ["Priority", "priority"])
        
        // Legacy column support
        let jobIdIndex = findColumnIndex(in: header, possibleNames: ["JobID", "jobid", "job_id", "Job ID"])
        let clientIndex = findColumnIndex(in: header, possibleNames: ["Client", "client"])
        let addressIndex = findColumnIndex(in: header, possibleNames: ["AddressLine1", "addressline1", "address", "Address"])
        let cityIndex = findColumnIndex(in: header, possibleNames: ["City", "city"])
        let stateIndex = findColumnIndex(in: header, possibleNames: ["State", "state"])
        let zipIndex = findColumnIndex(in: header, possibleNames: ["Zip", "zip", "ZIP"])
        let notesIndex = findColumnIndex(in: header, possibleNames: ["Notes", "notes"])
        
        // Determine if we're using new format (has Insured's Address) or old format
        let usingNewFormat = insuredAddressIndex != nil
        
        var jobs: [CSVJobData] = []
        
        for (index, line) in lines.enumerated() {
            // Skip header row and empty lines
            guard index > headerIndex, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            // Skip "Subitems" rows
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.lowercased().hasPrefix("subitems") {
                continue
            }
            
            // Parse line with proper CSV parsing (handles quoted fields)
            let columns = parseCSVLine(line, delimiter: delimiter)
            
            // Filter: Only process rows where Window Test Status is "Needs window Test" (case-insensitive)
            if usingNewFormat, let windowTestStatusIdx = windowTestStatusIndex,
               columns.indices.contains(windowTestStatusIdx) {
                let status = columns[windowTestStatusIdx].lowercased()
                if !status.contains("needs window test") && !status.contains("needs windowtest") {
                    continue // Skip this row
                }
            }
            
            if usingNewFormat {
                // New format: Parse address from Insured's Address or Name column
                var addressToParse: String = ""
                var addressSourceColumn: String = ""
                
                // Try Insured's Address first, then fall back to Name column
                if let insuredAddrIdx = insuredAddressIndex,
                   columns.indices.contains(insuredAddrIdx),
                   !columns[insuredAddrIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                    addressToParse = columns[insuredAddrIdx]
                    addressSourceColumn = "Insured's Address (index \(insuredAddrIdx))"
                } else if let nameIdx = nameIndex,
                          columns.indices.contains(nameIdx),
                          !columns[nameIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                    // Name column contains the address in this CSV format
                    addressToParse = columns[nameIdx]
                    addressSourceColumn = "Name (index \(nameIdx))"
                } else {
                    print("⚠️ [CSVImport] No address found in row \(index)")
                    continue
                }
                
                print("🔍 [CSVImport] Row \(index) - Reading address from \(addressSourceColumn): '\(addressToParse)'")
                print("   All columns: \(columns)")
                
                // Validate that this looks like an address (not notes/concerns)
                if !isValidAddress(addressToParse) {
                    print("⚠️ [CSVImport] Skipping row \(index) - doesn't look like an address: '\(addressToParse)'")
                    continue
                } else {
                    print("✅ [CSVImport] Address validation passed for: '\(addressToParse)'")
                }
                
                var parsedAddress = parseAddress(addressToParse)
                
                // Default state to FL if missing (all addresses are in Florida)
                if parsedAddress.state.isEmpty && !parsedAddress.city.isEmpty {
                    parsedAddress = (line1: parsedAddress.line1, city: parsedAddress.city, state: "FL", zip: parsedAddress.zip)
                }
                
                // Debug logging
                print("📋 [CSVImport] Parsed address: '\(addressToParse)' -> line1: '\(parsedAddress.line1)', city: '\(parsedAddress.city)', state: '\(parsedAddress.state)', zip: '\(parsedAddress.zip ?? "")'")
                
                // Use Insured's name field for client name (owner name), with fallbacks
                var clientNameValue = ""
                
                // Priority 1: Check for "Insured's name" column first
                if let insuredNameIdx = insuredNameIndex,
                   columns.indices.contains(insuredNameIdx),
                   !columns[insuredNameIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                    clientNameValue = columns[insuredNameIdx].trimmingCharacters(in: .whitespaces)
                    print("MYDEBUG → Using Insured's name column for owner name: '\(clientNameValue)'")
                }
                // Priority 2: Fall back to Name field if Insured's name not available
                else if let nameIdx = nameIndex,
                        columns.indices.contains(nameIdx),
                        !columns[nameIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                    let nameValue = columns[nameIdx].trimmingCharacters(in: .whitespaces)
                    // If Name column was used as address, skip it
                    if nameValue != addressToParse {
                        clientNameValue = nameValue
                        print("MYDEBUG → Using Name column for owner name: '\(clientNameValue)'")
                    }
                }
                
                // Priority 3: If still empty, try tenant name or use default
                if clientNameValue.isEmpty {
                    if let tenantName = tenantNameIndex.flatMap({ columns.indices.contains($0) ? columns[$0] : nil }),
                       !tenantName.isEmpty {
                        clientNameValue = tenantName
                        print("MYDEBUG → Using Tenant name as fallback for owner name: '\(clientNameValue)'")
                    } else {
                        clientNameValue = "Sunshine Portfolio"
                        print("MYDEBUG → Using default owner name: '\(clientNameValue)'")
                    }
                }
                
                let job = CSVJobData(
                    jobId: jobIdIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    name: nameIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    clientName: clientNameValue.isEmpty ? "Sunshine Portfolio" : clientNameValue,
                    addressLine1: parsedAddress.line1,
                    city: parsedAddress.city,
                    state: parsedAddress.state,
                    zip: parsedAddress.zip,
                    notes: buildNotesString(
                        inspectionDate: inspectionDateIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        windowTestStatus: windowTestStatusIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        roofReportStatus: roofReportStatusIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        moldConcerns: moldConcernsIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        tenantName: tenantNameIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        tenantPhone: tenantPhoneIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        additionalTenant: additionalTenantIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        email: emailIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                        priority: priorityIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil }
                    ),
                    inspectionDate: inspectionDateIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    windowTestStatus: windowTestStatusIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    roofReportStatus: roofReportStatusIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    moldConcerns: moldConcernsIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    tenantName: tenantNameIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    tenantPhone: tenantPhoneIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    additionalTenant: additionalTenantIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    email: emailIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    priority: priorityIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil }
                )
                
                jobs.append(job)
            } else {
                // Legacy format
                guard let client = clientIndex,
                      let address = addressIndex,
                      let city = cityIndex,
                      let state = stateIndex,
                      columns.count > max(client, address, city, state) else {
                    continue
                }
                
                // Parse city field in case it contains state and zip
                var cityValue = columns[city].trimmingCharacters(in: .whitespaces)
                var stateValue = columns[state].trimmingCharacters(in: .whitespaces)
                var zipValue = zipIndex.flatMap { columns.indices.contains($0) ? columns[$0].trimmingCharacters(in: .whitespaces) : nil }
                
                // If state and zip are empty but city might contain them, try to parse
                // Also check if city ends with state/zip pattern even if state/zip columns have values
                if !cityValue.isEmpty {
                    let cityParts = cityValue.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    
                    // Look for state abbreviation (2 letters, uppercase) followed by zip (5 digits)
                    // Search from the end backwards to find the last occurrence
                    for i in stride(from: cityParts.count - 1, through: 0, by: -1) {
                        let part = cityParts[i]
                        
                        // Check if it's a zip code (5 digits)
                        if part.count == 5, let _ = Int(part) {
                            // Found zip, check if previous part is state
                            if i > 0 {
                                let prevPart = cityParts[i - 1]
                                // Check if it's a state (2 letters, uppercase)
                                if prevPart.count == 2 && prevPart.allSatisfy({ $0.isLetter }) && prevPart.uppercased() == prevPart {
                                    // Found state and zip in city field
                                    // Only use these if state/zip columns are empty
                                    if stateValue.isEmpty {
                                        stateValue = prevPart
                                    }
                                    if zipValue == nil || zipValue!.isEmpty {
                                        zipValue = part
                                    }
                                    // City is everything before the state
                                    if i > 1 {
                                        cityValue = cityParts[0..<(i-1)].joined(separator: " ")
                                    } else {
                                        cityValue = ""
                                    }
                                    break
                                }
                            }
                        }
                        
                        // Also check if it's a state (2 letters, uppercase) followed by zip
                        if part.count == 2 && part.allSatisfy({ $0.isLetter }) && part.uppercased() == part {
                            // Found potential state, check if next part is zip
                            if i + 1 < cityParts.count {
                                let nextPart = cityParts[i + 1]
                                if nextPart.count == 5, let _ = Int(nextPart) {
                                    // Found state and zip in city field
                                    // Only use these if state/zip columns are empty
                                    if stateValue.isEmpty {
                                        stateValue = part
                                    }
                                    if zipValue == nil || zipValue!.isEmpty {
                                        zipValue = nextPart
                                    }
                                    // City is everything before the state
                                    if i > 0 {
                                        cityValue = cityParts[0..<i].joined(separator: " ")
                                    } else {
                                        cityValue = ""
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                
                let job = CSVJobData(
                    jobId: jobIdIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    name: nil,
                    clientName: columns[client],
                    addressLine1: columns[address],
                    city: cityValue,
                    state: stateValue,
                    zip: zipValue,
                    notes: notesIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil },
                    inspectionDate: nil,
                    windowTestStatus: nil,
                    roofReportStatus: nil,
                    moldConcerns: nil,
                    tenantName: nil,
                    tenantPhone: nil,
                    additionalTenant: nil,
                    email: nil,
                    priority: nil
                )
                
                jobs.append(job)
            }
        }
        
        return jobs
    }
    
    // Helper function to parse CSV line handling quoted fields
    private func parseCSVLine(_ line: String, delimiter: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var characters = Array(line)
        
        var i = 0
        while i < characters.count {
            let char = characters[i]
            
            if char == "\"" {
                if insideQuotes && i + 1 < characters.count && characters[i + 1] == "\"" {
                    // Escaped quote (double quote)
                    currentField += "\""
                    i += 2
                    continue
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                    i += 1
                    continue
                }
            }
            
            if !insideQuotes && String(char) == delimiter {
                // End of field
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                i += 1
                continue
            }
            
            currentField += String(char)
            i += 1
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
    
    // Helper function to find column index
    private func findColumnIndex(in header: [String], possibleNames: [String]) -> Int? {
        for name in possibleNames {
            if let index = header.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                return index
            }
        }
        return nil
    }
    
    // Helper function to validate if a string looks like an address
    private func isValidAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        
        let lowercased = trimmed.lowercased()
        
        // Check if it looks like notes/concerns FIRST (before other checks)
        // These are strong indicators it's not an address
        let noteIndicators = ["water stains", "bathroom", "ceiling", "kitchen", "living room", 
                             "bedroom", "crack", "mold", "stains on", "tenant", "vacant", "has water"]
        let hasNoteIndicators = noteIndicators.contains(where: { lowercased.contains($0) })
        
        // Check if it contains street indicators (strong indicator it IS an address)
        // Use word boundaries to avoid false matches (e.g., "stains" shouldn't match "st")
        let addressIndicators = [" st", " street", " ave", " avenue", " rd", " road", " dr", " drive", 
                                 " blvd", " boulevard", " ln", " lane", " ct", " court", " way", " pl", " place"]
        // Check for street indicators with word boundaries (space before, followed by space/punctuation/end)
        let hasStreetIndicators = addressIndicators.contains { indicator in
            if let range = lowercased.range(of: indicator) {
                // Check that it's followed by space, punctuation, or end of string (not part of another word)
                let afterRange = range.upperBound
                if afterRange < lowercased.endIndex {
                    let afterChar = lowercased[afterRange]
                    // If followed by letter, it's part of another word (e.g., "stains" contains "st")
                    if afterChar.isLetter {
                        return false
                    }
                }
                return true
            }
            return false
        }
        
        print("🔍 [Validation] Checking: '\(trimmed)'")
        print("   hasNoteIndicators: \(hasNoteIndicators), hasStreetIndicators: \(hasStreetIndicators)")
        
        // If it has note indicators but NO street indicators, reject it
        if hasNoteIndicators && !hasStreetIndicators {
            print("🔍 [Validation] Rejecting - has note indicators but no street indicators: '\(trimmed)'")
            return false
        }
        
        // Check if it contains phone number patterns (likely wrong column)
        let phonePattern = #"\d{10,}"#
        if address.range(of: phonePattern, options: .regularExpression) != nil {
            return false
        }
        
        // Check if it starts with a number (most addresses do)
        let firstChar = trimmed.prefix(1)
        if firstChar.allSatisfy({ $0.isNumber }) {
            return true
        }
        
        // Check if it starts with common street prefixes (N, S, E, W, North, South, etc.)
        let streetPrefixes = ["n ", "s ", "e ", "w ", "north ", "south ", "east ", "west "]
        if streetPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        
        // If it has street indicators, it's likely an address
        if hasStreetIndicators {
            return true
        }
        
        // Check if it starts with "Apt" or "Unit" followed by a valid unit identifier
        // This could be a valid address if it's part of a larger address string
        // But if it's just "Apt B water stains..." it's not valid
        if lowercased.hasPrefix("apt ") || lowercased.hasPrefix("unit ") {
            // Check if there's more address-like content after the unit
            let afterUnit = String(lowercased.dropFirst(4)) // Drop "apt " or "unit "
            // If it immediately goes into notes/concerns, reject
            if noteIndicators.contains(where: { afterUnit.contains($0) }) && !hasStreetIndicators {
                return false
            }
            // If it has street indicators elsewhere, it might be valid
            if hasStreetIndicators {
                return true
            }
        }
        
        // Default: reject if it doesn't clearly look like an address
        return false
    }
    
    // Helper function to detect if a word sequence contains a unit pattern
    // Returns a tuple: (startIndex, endIndex) where the unit pattern is, or nil if not found
    // The endIndex is the index AFTER the last word of the unit pattern
    private func findUnitPatternRange(in words: [String], startingFrom: Int) -> (start: Int, end: Int)? {
        // Check backwards from startingFrom for unit patterns
        // Patterns: "Unit A & B", "Unit A&B", "Unit A and B", "Unit A, B", etc.
        if startingFrom < 1 { return nil }
        
        // Check for "Unit" followed by unit identifier(s)
        for i in stride(from: min(startingFrom, words.count - 1), through: 0, by: -1) {
            let word = words[i].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            
            // Check if this word is "unit"
            if word == "unit" && i < words.count - 1 {
                // Found "Unit", check what follows to determine where the pattern ends
                var patternEndIndex = i + 1 // Default: just "Unit"
                
                    // Check for patterns like "Unit A & B", "Unit A&B", or "Unit A-B"
                    if i + 1 < words.count {
                        let nextWord = words[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                        patternEndIndex = i + 2 // "Unit A"
                        
                        // Check for hyphenated pattern "Unit A-B" (e.g., "A-B", "1A-1B")
                        // This should have been normalized earlier, but handle as fallback
                        if nextWord.contains("-") {
                            // Found "Unit A-B" pattern - the hyphenated part is a single word
                            // Pattern ends after this word
                            patternEndIndex = i + 2
                            return (start: i, end: patternEndIndex)
                        }
                        
                        // Check for "&" or "and" pattern
                        if i + 2 < words.count {
                            let thirdWord = words[i + 2].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                            if thirdWord == "&" || thirdWord == "and" {
                                // Found "Unit A &" or "Unit A and"
                                if i + 3 < words.count {
                                    patternEndIndex = i + 4 // "Unit A & B" or "Unit A and B"
                                } else {
                                    patternEndIndex = i + 3 // "Unit A &" (incomplete, but still a pattern)
                                }
                                return (start: i, end: patternEndIndex)
                            }
                        }
                        
                        // Check for comma-separated pattern "Unit A, B"
                        if i + 2 < words.count {
                            let thirdWord = words[i + 2].trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                            if thirdWord.count == 1 && thirdWord.allSatisfy({ $0.isLetter || $0.isNumber }) {
                                // Likely "Unit A, B" pattern
                                patternEndIndex = i + 3
                                return (start: i, end: patternEndIndex)
                            }
                        }
                        
                        // Simple "Unit A" or "Unit 1" pattern
                        let firstUnitPart = nextWord
                        if firstUnitPart.count <= 5 && (firstUnitPart.allSatisfy({ $0.isLetter || $0.isNumber }) || firstUnitPart.contains(",")) {
                            return (start: i, end: patternEndIndex)
                        }
                    }
            }
        }
        
        return nil
    }
    
    // Helper function to parse address string into components
    private func parseAddress(_ addressString: String) -> (line1: String, city: String, state: String, zip: String?) {
        // Remove quotes if present
        var address = addressString.trimmingCharacters(in: .whitespaces)
        if address.hasPrefix("\"") && address.hasSuffix("\"") {
            address = String(address.dropFirst().dropLast())
        }
        
        // Normalize unit patterns: "Unit A-B" -> "Unit A & B", "Apt A-B" -> "Apt A & B"
        // Use regex to find and replace hyphenated unit patterns
        let hyphenatedUnitPatterns = [
            (#"Unit\s+([A-Z0-9]+)-([A-Z0-9]+)"#, "Unit $1 & $2"),
            (#"Apt\s+([A-Z0-9]+)-([A-Z0-9]+)"#, "Apt $1 & $2"),
            (#"Apartment\s+([A-Z0-9]+)-([A-Z0-9]+)"#, "Apartment $1 & $2")
        ]
        
        for (pattern, replacement) in hyphenatedUnitPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(address.startIndex..., in: address)
                address = regex.stringByReplacingMatches(in: address, options: [], range: range, withTemplate: replacement)
            }
        }
        
        // Common formats:
        // "5018 E 122nd Ave. Temple Terrace 33617" (no commas, city and zip in same field)
        // "123 Main St, City, ST 12345" (with commas)
        // "123 Main St, City, ST" (with commas, no zip)
        
        let components = address.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var line1 = address
        var city = ""
        var state = ""
        var zip: String? = nil
        
        if components.count >= 3 {
            // Format: "123 Main St, City, ST 12345"
            line1 = components[0]
            city = components[1]
            
            // Last component might be "ST 12345" or just "ST"
            let stateZip = components[2]
            let stateZipParts = stateZip.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if stateZipParts.count >= 1 {
                state = stateZipParts[0]
            }
            if stateZipParts.count >= 2 {
                zip = stateZipParts[1]
            }
        } else if components.count == 2 {
            // Format: "123 Main St, City" or "123 Main St City, FL 12345" or "123 Main St, FL 12345"
            line1 = components[0]
            let secondComponent = components[1]
            
            // Parse second component for state/zip pattern
            let secondParts = secondComponent.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Check if second component contains state/zip pattern
            var foundStateZip = false
            for i in stride(from: secondParts.count - 1, through: 0, by: -1) {
                let part = secondParts[i]
                
                // Check if it's a zip code (5 digits)
                if part.count == 5, let _ = Int(part) {
                    // Found zip, check if previous part is state
                    if i > 0 {
                        let prevPart = secondParts[i - 1]
                        // Check if it's a state (2 letters, uppercase or lowercase)
                        if prevPart.count == 2 && prevPart.allSatisfy({ $0.isLetter }) {
                            // Found state and zip in second component
                            state = prevPart.uppercased()
                            zip = part
                            // City is everything before state in second component, or extract from first component
                            if i > 1 {
                                // There's content before state+zip in second component, use that as city
                                city = secondParts[0..<(i-1)].joined(separator: " ")
                            } else {
                                // Second component is just state+zip, extract city from end of first component
                                // (e.g., "9309 N. 21 St. Tampa" -> "Tampa")
                                // BUT: Check for unit patterns first (e.g., "333 N Street Unit A & B Tampa")
                                let firstParts = components[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                                if firstParts.count > 1 {
                                    // Check if there's a unit pattern
                                    if let unitRange = findUnitPatternRange(in: firstParts, startingFrom: firstParts.count - 1) {
                                        // Found unit pattern - extract city from after the unit pattern
                                        // Example: "333 N Street Unit A & B Tampa" -> city should be "Tampa" (after unit)
                                        if unitRange.end < firstParts.count {
                                            // There are words after the unit pattern - those are the city
                                            let wordsAfterUnit = Array(firstParts[unitRange.end...])
                                            if wordsAfterUnit.count > 0 {
                                                let potentialCity = wordsAfterUnit.joined(separator: " ")
                                                let cleanCity = potentialCity.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                                if cleanCity.count > 2 && !cleanCity.allSatisfy({ $0.isNumber }) {
                                                    city = cleanCity
                                                    line1 = firstParts[0..<unitRange.end].joined(separator: " ")
                                                } else {
                                                    city = ""
                                                }
                                            } else {
                                                city = ""
                                            }
                                        } else {
                                            // Unit pattern is at the end, no city in first component
                                            city = ""
                                        }
                                    } else {
                                        // No unit pattern, proceed with normal city extraction
                                        let lastWord = firstParts[firstParts.count - 1]
                                        // Remove common punctuation
                                        let cleanLastWord = lastWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                        
                                        // If it doesn't look like part of street address, it's likely the city
                                        let lowerLast = cleanLastWord.lowercased()
                                        if !lowerLast.hasSuffix("st") && 
                                           !lowerLast.hasSuffix("ave") && 
                                           !lowerLast.hasSuffix("rd") && 
                                           !lowerLast.hasSuffix("dr") &&
                                           !lowerLast.hasSuffix("blvd") &&
                                           !lowerLast.hasSuffix("ln") &&
                                           !lowerLast.hasSuffix("ct") &&
                                           !lowerLast.hasSuffix("way") &&
                                           !lowerLast.hasSuffix("pl") &&
                                           cleanLastWord.count > 2 &&
                                           !cleanLastWord.allSatisfy({ $0.isNumber }) {
                                            city = cleanLastWord
                                            line1 = firstParts[0..<(firstParts.count - 1)].joined(separator: " ")
                                        } else {
                                            // Try second-to-last word if last word looks like street type
                                            if firstParts.count > 2 {
                                                let secondLastWord = firstParts[firstParts.count - 2]
                                                let cleanSecondLast = secondLastWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                                if cleanSecondLast.count > 2 && !cleanSecondLast.allSatisfy({ $0.isNumber }) {
                                                    city = cleanSecondLast
                                                    line1 = firstParts[0..<(firstParts.count - 2)].joined(separator: " ")
                                                } else {
                                                    city = ""
                                                }
                                            } else {
                                                city = ""
                                            }
                                        }
                                    }
                                } else {
                                    city = ""
                                }
                            }
                            foundStateZip = true
                            break
                        }
                    } else {
                        // Component 1 is just a zip code (no state) - extract city from component 0
                        // Example: "1605 E. Kirby St. Unit A & B Tampa, 33604"
                        zip = part
                        let firstParts = components[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if firstParts.count > 1 {
                            // Check if there's a unit pattern
                            if let unitRange = findUnitPatternRange(in: firstParts, startingFrom: firstParts.count - 1) {
                                // Found unit pattern - extract city from after the unit pattern
                                if unitRange.end < firstParts.count {
                                    let wordsAfterUnit = Array(firstParts[unitRange.end...])
                                    if wordsAfterUnit.count > 0 {
                                        let potentialCity = wordsAfterUnit.joined(separator: " ")
                                        let cleanCity = potentialCity.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                        if cleanCity.count > 2 && !cleanCity.allSatisfy({ $0.isNumber }) {
                                            city = cleanCity
                                            line1 = firstParts[0..<unitRange.end].joined(separator: " ")
                                        }
                                    }
                                }
                            } else {
                                // No unit pattern, extract city from end
                                let lastWord = firstParts[firstParts.count - 1]
                                let cleanLastWord = lastWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                let lowerLast = cleanLastWord.lowercased()
                                if !lowerLast.hasSuffix("st") && 
                                   !lowerLast.hasSuffix("ave") && 
                                   !lowerLast.hasSuffix("rd") && 
                                   !lowerLast.hasSuffix("dr") &&
                                   !lowerLast.hasSuffix("blvd") &&
                                   !lowerLast.hasSuffix("ln") &&
                                   !lowerLast.hasSuffix("ct") &&
                                   !lowerLast.hasSuffix("way") &&
                                   !lowerLast.hasSuffix("pl") &&
                                   cleanLastWord.count > 2 &&
                                   !cleanLastWord.allSatisfy({ $0.isNumber }) {
                                    city = cleanLastWord
                                    line1 = firstParts[0..<(firstParts.count - 1)].joined(separator: " ")
                                }
                            }
                        }
                        foundStateZip = true
                        break
                    }
                }
                
                // Check if it's a state (2 letters) followed by zip
                if part.count == 2 && part.allSatisfy({ $0.isLetter }) {
                    // Check if next part is zip
                    if i + 1 < secondParts.count {
                        let nextPart = secondParts[i + 1]
                        if nextPart.count == 5, let _ = Int(nextPart) {
                            // Found state and zip
                            state = part.uppercased()
                            zip = nextPart
                            // City is everything before state in second component, or extract from first component
                            if i > 0 {
                                // There's content before state+zip in second component, use that as city
                                city = secondParts[0..<i].joined(separator: " ")
                            } else {
                                // Second component is just state+zip, extract city from end of first component
                                // Check for unit patterns first
                                let firstParts = components[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                                if firstParts.count > 1 {
                                    // Check if there's a unit pattern
                                    if let unitRange = findUnitPatternRange(in: firstParts, startingFrom: firstParts.count - 1) {
                                        // Found unit pattern - extract city from after the unit pattern
                                        if unitRange.end < firstParts.count {
                                            let wordsAfterUnit = Array(firstParts[unitRange.end...])
                                            if wordsAfterUnit.count > 0 {
                                                let potentialCity = wordsAfterUnit.joined(separator: " ")
                                                let cleanCity = potentialCity.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                                if cleanCity.count > 2 && !cleanCity.allSatisfy({ $0.isNumber }) {
                                                    city = cleanCity
                                                    line1 = firstParts[0..<unitRange.end].joined(separator: " ")
                                                } else {
                                                    city = ""
                                                }
                                            } else {
                                                city = ""
                                            }
                                        } else {
                                            city = ""
                                        }
                                    } else {
                                        // No unit pattern, proceed with normal city extraction
                                        let lastWord = firstParts[firstParts.count - 1]
                                        // Remove common punctuation
                                        let cleanLastWord = lastWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                        
                                        // If it doesn't look like part of street address, it's likely the city
                                        let lowerLast = cleanLastWord.lowercased()
                                        if !lowerLast.hasSuffix("st") && 
                                           !lowerLast.hasSuffix("ave") && 
                                           !lowerLast.hasSuffix("rd") && 
                                           !lowerLast.hasSuffix("dr") &&
                                           !lowerLast.hasSuffix("blvd") &&
                                           !lowerLast.hasSuffix("ln") &&
                                           !lowerLast.hasSuffix("ct") &&
                                           !lowerLast.hasSuffix("way") &&
                                           !lowerLast.hasSuffix("pl") &&
                                           cleanLastWord.count > 2 &&
                                           !cleanLastWord.allSatisfy({ $0.isNumber }) {
                                            city = cleanLastWord
                                            line1 = firstParts[0..<(firstParts.count - 1)].joined(separator: " ")
                                        } else {
                                            // Try second-to-last word if last word looks like street type
                                            if firstParts.count > 2 {
                                                let secondLastWord = firstParts[firstParts.count - 2]
                                                let cleanSecondLast = secondLastWord.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                                                if cleanSecondLast.count > 2 && !cleanSecondLast.allSatisfy({ $0.isNumber }) {
                                                    city = cleanSecondLast
                                                    line1 = firstParts[0..<(firstParts.count - 2)].joined(separator: " ")
                                                } else {
                                                    city = ""
                                                }
                                            } else {
                                                city = ""
                                            }
                                        }
                                    }
                                } else {
                                    city = ""
                                }
                            }
                            foundStateZip = true
                            break
                        }
                    }
                }
            }
            
            // If we didn't find state/zip pattern, treat second component as city
            if !foundStateZip {
                city = secondComponent
            }
        } else {
            // No commas - try to parse "5018 E 122nd Ave. Temple Terrace 33617"
            // Or "333 N Street Unit A & B Tampa 33604"
            // Look for state abbreviation (2 letters) or zip code (5 digits)
            let parts = address.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if parts.count >= 2 {
                // Try to find zip (last 5-digit number) or state (2-letter abbreviation)
                var foundZip = false
                for i in stride(from: parts.count - 1, through: 0, by: -1) {
                    let part = parts[i]
                    
                    // Check if it's a zip code (5 digits)
                    if part.count == 5, let _ = Int(part) {
                        zip = part
                        foundZip = true
                        // Extract city and address
                        if i > 0 {
                            // Check for unit pattern before extracting city
                            if let unitRange = findUnitPatternRange(in: parts, startingFrom: i - 1) {
                                // Found unit pattern - city is after the unit pattern, before zip
                                if unitRange.end < i {
                                    // There are words between unit pattern end and zip - those are the city
                                    let cityParts = Array(parts[unitRange.end..<i])
                                    if cityParts.count > 0 {
                                        city = cityParts.joined(separator: " ")
                                        line1 = parts[0..<unitRange.end].joined(separator: " ")
                                    } else {
                                        city = ""
                                        line1 = parts[0..<i].joined(separator: " ")
                                    }
                                } else {
                                    // Unit pattern ends at or after zip position, no city
                                    city = ""
                                    line1 = parts[0..<i].joined(separator: " ")
                                }
                            } else if i >= 2 {
                                // No unit pattern, proceed with normal city extraction
                                // Try to extract city - could be one or two words before zip
                                // Common pattern: "Street City Zip" or "Street City Name Zip"
                                // For "5018 E 122nd Ave. Temple Terrace 33617", we want "Temple Terrace" as city
                                // Try two words first (most common for city names)
                                if i >= 2 {
                                    let potentialCity = parts[i-2..<i].joined(separator: " ")
                                    // If the word before zip looks like a city name (not a number or abbreviation)
                                    if !parts[i-1].allSatisfy({ $0.isNumber }) && parts[i-1].count > 2 {
                                        city = potentialCity
                                        line1 = parts[0..<(i-2)].joined(separator: " ")
                                    } else {
                                        // Fall back to single word
                                        city = parts[i-1]
                                        line1 = parts[0..<(i-1)].joined(separator: " ")
                                    }
                                } else {
                                    city = parts[i-1]
                                    line1 = parts[0..<(i-1)].joined(separator: " ")
                                }
                            } else {
                                city = parts[i-1]
                                line1 = parts[0]
                            }
                        }
                        break
                    }
                    
                    // Check if it's a state (2 letters, uppercase)
                    if part.count == 2 && part.allSatisfy({ $0.isLetter }) && part.uppercased() == part {
                        state = part
                        if i > 0 {
                            // City is likely the part before state
                            if i > 1 {
                                city = parts[i-1]
                                line1 = parts[0..<(i-1)].joined(separator: " ")
                            } else {
                                line1 = parts[0]
                            }
                        }
                        // Check if there's a zip after state
                        if i + 1 < parts.count {
                            let nextPart = parts[i + 1]
                            if nextPart.count == 5, let _ = Int(nextPart) {
                                zip = nextPart
                            }
                        }
                        break
                    }
                }
                
                // If we didn't find state/zip, treat everything as address line 1
                if !foundZip && state.isEmpty {
                    line1 = address
                }
            } else {
                line1 = address
            }
        }
        
        return (line1: line1, city: city, state: state, zip: zip)
    }
    
    // Helper function to build notes string from all the additional fields
    private func buildNotesString(
        inspectionDate: String?,
        windowTestStatus: String?,
        roofReportStatus: String?,
        moldConcerns: String?,
        tenantName: String?,
        tenantPhone: String?,
        additionalTenant: String?,
        email: String?,
        priority: String?
    ) -> String? {
        var notes: [String] = []
        
        if let date = inspectionDate, !date.isEmpty {
            notes.append("Inspection Date: \(date)")
        }
        if let status = windowTestStatus, !status.isEmpty {
            notes.append("Window Test Status: \(status)")
        }
        if let roof = roofReportStatus, !roof.isEmpty {
            notes.append("Roof Report Status: \(roof)")
        }
        if let mold = moldConcerns, !mold.isEmpty {
            notes.append("Mold Concerns: \(mold)")
        }
        if let tenant = tenantName, !tenant.isEmpty {
            notes.append("Tenant: \(tenant)")
        }
        if let phone = tenantPhone, !phone.isEmpty {
            notes.append("Tenant Phone: \(phone)")
        }
        if let addTenant = additionalTenant, !addTenant.isEmpty {
            notes.append("Additional Tenant: \(addTenant)")
        }
        if let emailAddr = email, !emailAddr.isEmpty {
            notes.append("Email: \(emailAddr)")
        }
        if let pri = priority, !pri.isEmpty {
            notes.append("Priority: \(pri)")
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "\n")
    }
}

struct CSVJobData {
    let jobId: String?
    let name: String?
    let clientName: String
    let addressLine1: String
    let city: String
    let state: String
    let zip: String?
    let notes: String?
    // New format fields
    let inspectionDate: String?
    let windowTestStatus: String?
    let roofReportStatus: String?
    let moldConcerns: String?
    let tenantName: String?
    let tenantPhone: String?
    let additionalTenant: String?
    let email: String?
    let priority: String?
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

