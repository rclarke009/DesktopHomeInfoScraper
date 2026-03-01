//
//  NamedStormEditView.swift
//  DesktopHomeInfoScraper
//
//  Edit-Job-style screen for Named Storm: storm name, date, weather source, weather text, weather image.
//

import SwiftUI
import CoreData
import AppKit
import UniformTypeIdentifiers

struct NamedStormEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let job: Job

    @State private var selectedStormPickerId: String = ""
    @State private var customStormName: String = ""
    @State private var stormDate: Date = Date()
    @State private var weatherSourceText: String = ""
    @State private var customWeatherText: String = ""
    @State private var editingSelectedImage: NSImage?
    @State private var showingImagePicker = false

    private var pickerItems: [StormCatalogService.StormPickerItem] {
        StormCatalogService.unifiedStormPickerItems(context: viewContext)
    }

    private var selectedCatalogStorm: CatalogStorm? {
        guard selectedStormPickerId.hasPrefix("catalog:"),
              selectedStormPickerId.count > 8 else { return nil }
        let uuidString = String(selectedStormPickerId.dropFirst(8))
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        return StormCatalogService.fetchCatalogStorm(byId: uuid, context: viewContext)
    }

    /// Resolved storm name for display/save
    private var resolvedStormName: String {
        if selectedStormPickerId == "other" {
            return customStormName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let item = pickerItems.first(where: { $0.id == selectedStormPickerId }) {
            return item.displayName
        }
        return ""
    }

    private var jobUniqueId: String {
        (job.jobId ?? "").isEmpty ? UUID().uuidString : (job.jobId ?? UUID().uuidString)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                Form {
                Section("Storm") {
                    Picker("Storm name", selection: $selectedStormPickerId) {
                        Text("— Select —").tag("")
                        ForEach(pickerItems, id: \.id) { item in
                            Text(item.displayName).tag(item.id)
                        }
                    }
                    .onChange(of: selectedStormPickerId) { _, newValue in
                        if let item = pickerItems.first(where: { $0.id == newValue }), let date = item.date {
                            stormDate = date
                        }
                    }

                    if selectedStormPickerId == "other" {
                        TextField("Custom storm name", text: $customStormName)
                    }

                    DatePicker("Storm date", selection: $stormDate, displayedComponents: .date)
                }

                if let catalogStorm = selectedCatalogStorm {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Images from catalog")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            let images = StormCatalogService.orderedImages(for: catalogStorm)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(images, id: \.objectID) { img in
                                        if let nsImage = StormCatalogService.loadImage(for: img) {
                                            VStack(spacing: 6) {
                                                Image(nsImage: nsImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 120, height: 80)
                                                    .clipped()
                                                    .cornerRadius(8)
                                                Button("Use this image", action: {
                                                    StormCatalogService.copyCatalogImageToJob(img, job: job, context: viewContext)
                                                    editingSelectedImage = StormCatalogService.loadImage(for: img)
                                                })
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            if let defaultWeather = catalogStorm.defaultWeatherText, !defaultWeather.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default weather text")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button("Use this text", action: {
                                        customWeatherText = defaultWeather
                                    })
                                    .buttonStyle(.bordered)
                                }
                            }
                            if let defaultSource = catalogStorm.defaultSourceText, !defaultSource.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default source")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button("Use this source", action: {
                                        weatherSourceText = defaultSource
                                    })
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    } header: {
                        Text("Storm resources")
                    }
                }

                Section {
                    TextEditor(text: $weatherSourceText)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Text("Source for citation #3 (SOURCES page). Leave empty to use default NHC citation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Weather source")
                }

                Section {
                    TextEditor(text: $customWeatherText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Text("Leave empty to use default weather narrative (uses storm name and date above).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Custom weather text")
                }

                Section {
                    if let previewImage = editingSelectedImage ?? loadCustomHurricaneImage() {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }

                    HStack(spacing: 12) {
                        Button(action: { showingImagePicker = true }) {
                            HStack {
                                Image(systemName: "photo")
                                Text(hasCustomHurricaneImageOrPreview() ? "Replace Image" : "Select Image")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if hasCustomHurricaneImageOrPreview() {
                            Button(action: {
                                editingSelectedImage = nil
                                removeCustomHurricaneImage()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } header: {
                    Text("Weather image")
                }
                }
            }
            .navigationTitle("Named Storm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: handleSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadInitialValues()
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.jpeg, .png, .heic, .tiff, .bmp, .gif],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let image = NSImage(contentsOf: url) {
                        editingSelectedImage = image
                    }
                }
            case .failure(let error):
                print("MYDEBUG → NamedStormEditView image picker failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadInitialValues() {
        let name = (job.namedStormName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let items = pickerItems
        if name.isEmpty {
            selectedStormPickerId = ""
            stormDate = job.namedStormDate ?? Date()
        } else if let catalog = StormCatalogService.fetchAllCatalogStorms(context: viewContext).first(where: { ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == name }),
                  let catalogId = catalog.id {
            selectedStormPickerId = "catalog:\(catalogId.uuidString)"
            stormDate = catalog.stormDate ?? job.namedStormDate ?? Date()
        } else if let item = items.first(where: { $0.displayName == name }) {
            selectedStormPickerId = item.id
            stormDate = item.date ?? job.namedStormDate ?? Date()
        } else {
            selectedStormPickerId = "other"
            customStormName = name
            stormDate = job.namedStormDate ?? Date()
        }
        weatherSourceText = job.namedStormWeatherSource ?? ""
        customWeatherText = job.customWeatherText ?? ""
    }

    private func hasCustomHurricaneImage() -> Bool {
        guard let imagePath = job.customHurricaneImagePath else { return false }
        return loadCustomHurricaneImage(from: imagePath) != nil
    }

    private func hasCustomHurricaneImageOrPreview() -> Bool {
        editingSelectedImage != nil || hasCustomHurricaneImage()
    }

    private func loadCustomHurricaneImage() -> NSImage? {
        guard let imagePath = job.customHurricaneImagePath else { return nil }
        return loadCustomHurricaneImage(from: imagePath)
    }

    private func customHurricaneImagesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_hurricane_images")
    }

    private func loadCustomHurricaneImage(from imagePath: String) -> NSImage? {
        let imageURL = customHurricaneImagesDirectory().appendingPathComponent(imagePath)
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private func removeCustomHurricaneImage() {
        if let imagePath = job.customHurricaneImagePath {
            let imageURL = customHurricaneImagesDirectory().appendingPathComponent(imagePath)
            try? FileManager.default.removeItem(at: imageURL)
        }
        job.customHurricaneImagePath = nil
        do {
            try viewContext.save()
        } catch {
            print("MYDEBUG → Failed to remove custom hurricane image: \(error.localizedDescription)")
        }
    }

    private func saveCustomHurricaneImage(_ image: NSImage, for job: Job) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("MYDEBUG → Failed to get JPEG data from NSImage")
            return
        }
        let imagesDirectory = customHurricaneImagesDirectory()
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let fileName = "\(jobUniqueId)_custom_hurricane.jpg"
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            try imageData.write(to: fileURL)
            job.customHurricaneImagePath = fileName
            try viewContext.save()
        } catch {
            print("MYDEBUG → Failed to save custom hurricane image: \(error.localizedDescription)")
        }
    }

    private func handleSave() {
        let name = resolvedStormName
        job.namedStormName = name.isEmpty ? nil : name
        job.namedStormDate = name.isEmpty ? nil : stormDate

        let sourceTrimmed = weatherSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        job.namedStormWeatherSource = sourceTrimmed.isEmpty ? nil : weatherSourceText

        let weatherTrimmed = customWeatherText.trimmingCharacters(in: .whitespacesAndNewlines)
        job.customWeatherText = weatherTrimmed.isEmpty ? nil : customWeatherText

        if let image = editingSelectedImage {
            saveCustomHurricaneImage(image, for: job)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("MYDEBUG → Failed to save Named Storm: \(error.localizedDescription)")
        }
    }
}
