//
//  StormCatalogEditView.swift
//  DesktopHomeInfoScraper
//
//  Add or edit a catalog storm: name, date, default weather/source text, multiple images.
//

import SwiftUI
import CoreData
import AppKit
import UniformTypeIdentifiers

enum StormCatalogEditMode {
    case add
    case edit
}

struct StormCatalogEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let mode: StormCatalogEditMode
    let storm: CatalogStorm?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var stormDate: Date = Date()
    @State private var defaultWeatherText: String = ""
    @State private var defaultSourceText: String = ""
    @State private var showingImagePicker = false
    @State private var imageToDelete: CatalogStormImage?
    @State private var showingDeleteImageConfirmation = false
    @State private var showingDuplicateNameAlert = false
    /// When adding a storm, we create it on first "Add image" so images can be added in the same window.
    @State private var createdStormForAdd: CatalogStorm?

    private var isEditing: Bool { mode == .edit && storm != nil }

    /// The storm to use for the Images section: existing (edit) or the one we created in add mode.
    private var stormForImages: CatalogStorm? { storm ?? createdStormForAdd }

    private var nameMatchesKnownStorm: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        return StormHelpers.loadKnownStorms().contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }
    }

    private var orderedImages: [CatalogStormImage] {
        guard let s = stormForImages else { return [] }
        return StormCatalogService.orderedImages(for: s)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Storm") {
                    TextField("Storm name", text: $name)
                    if nameMatchesKnownStorm {
                        Text("This name is in the built-in storm list. Adding it to the catalog lets you attach images and default text for reports.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    DatePicker("Storm date", selection: $stormDate, displayedComponents: .date)
                }

                Section {
                    TextEditor(text: $defaultWeatherText)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Text("Default weather narrative for reports. Users can override when they pick this storm.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Default weather text")
                }

                Section {
                    TextEditor(text: $defaultSourceText)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Text("Default source for citation #3 (SOURCES page).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Default source text")
                }

                if stormForImages != nil {
                    Section {
                        ForEach(orderedImages, id: \.objectID) { img in
                            CatalogImageRow(
                                image: img,
                                isPrimary: img.isPrimary,
                                onSetPrimary: {
                                    StormCatalogService.setPrimaryImage(img, context: viewContext)
                                },
                                onDelete: {
                                    imageToDelete = img
                                    showingDeleteImageConfirmation = true
                                }
                            )
                        }
                        Button(action: { addImageTapped() }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add image")
                            }
                        }
                    } header: {
                        Text("Images")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if createdStormForAdd != nil {
                                Text("Storm was created so you can add images. Save to keep changes.")
                                    .foregroundColor(.secondary)
                            }
                            Text("First image or the one marked primary is used as the default report image when a user picks this storm.")
                        }
                    }
                } else {
                    Section {
                        Button(action: { addImageTapped() }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add storm image")
                            }
                        }
                        Text("Add at least one image for this storm. The storm will be created so you can add images in this window.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Images")
                    }
                }
            }
            .padding(.horizontal, 20)
            .navigationTitle(isEditing ? "Edit Storm" : "Add Storm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    if let url = urls.first, let s = stormForImages {
                        _ = StormCatalogService.addImage(
                            to: s,
                            sourceURL: url,
                            caption: nil,
                            isPrimary: orderedImages.isEmpty,
                            context: viewContext
                        )
                    }
                case .failure(let error):
                    print("MYDEBUG → StormCatalogEditView image picker failed: \(error.localizedDescription)")
                }
            }
            .alert("Remove image?", isPresented: $showingDeleteImageConfirmation, presenting: imageToDelete) { _ in
                Button("Cancel", role: .cancel) {
                    imageToDelete = nil
                }
                Button("Remove", role: .destructive) {
                    if let img = imageToDelete {
                        StormCatalogService.removeImage(img, context: viewContext)
                        imageToDelete = nil
                    }
                }
            } message: { _ in
                Text("This image will be removed from the catalog.")
            }
            .alert("Duplicate storm name", isPresented: $showingDuplicateNameAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A storm named \"\(name.trimmingCharacters(in: .whitespacesAndNewlines))\" is already in the catalog. Use a different name or edit the existing storm.")
            }
        }
    }

    private func loadInitialValues() {
        if let s = storm {
            name = s.name ?? ""
            stormDate = s.stormDate ?? Date()
            defaultWeatherText = s.defaultWeatherText ?? ""
            defaultSourceText = s.defaultSourceText ?? ""
        }
    }

    /// Called when user taps Add image. In add mode with no storm yet, create the storm first (requires non-empty name).
    private func addImageTapped() {
        if stormForImages != nil {
            showingImagePicker = true
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if StormCatalogService.catalogStormNameExists(trimmedName, excludingStormId: nil, context: viewContext) {
            showingDuplicateNameAlert = true
            return
        }
        guard let newStorm = StormCatalogService.createCatalogStorm(
            name: trimmedName,
            stormDate: stormDate,
            defaultWeatherText: defaultWeatherText.isEmpty ? nil : defaultWeatherText,
            defaultSourceText: defaultSourceText.isEmpty ? nil : defaultSourceText,
            context: viewContext
        ) else { return }
        createdStormForAdd = newStorm
        showingImagePicker = true
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let excludingId: UUID? = storm?.id ?? createdStormForAdd?.id
        if StormCatalogService.catalogStormNameExists(trimmedName, excludingStormId: excludingId, context: viewContext) {
            showingDuplicateNameAlert = true
            return
        }

        if let s = storm ?? createdStormForAdd {
            StormCatalogService.updateCatalogStorm(
                s,
                name: trimmedName,
                stormDate: stormDate,
                defaultWeatherText: defaultWeatherText.isEmpty ? nil : defaultWeatherText,
                defaultSourceText: defaultSourceText.isEmpty ? nil : defaultSourceText,
                context: viewContext
            )
        } else {
            _ = StormCatalogService.createCatalogStorm(
                name: trimmedName,
                stormDate: stormDate,
                defaultWeatherText: defaultWeatherText.isEmpty ? nil : defaultWeatherText,
                defaultSourceText: defaultSourceText.isEmpty ? nil : defaultSourceText,
                context: viewContext
            )
        }
        onDismiss()
    }
}

struct CatalogImageRow: View {
    let image: CatalogStormImage
    let isPrimary: Bool
    let onSetPrimary: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let nsImage = StormCatalogService.loadImage(for: image) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                if isPrimary {
                    Text("Primary (default for report)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    if !isPrimary {
                        Button("Set as primary", action: onSetPrimary)
                            .font(.caption)
                    }
                    Button("Remove", role: .destructive, action: onDelete)
                        .font(.caption)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
