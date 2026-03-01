//
//  StormCatalogService.swift
//  DesktopHomeInfoScraper
//
//  CRUD for storm catalog, image storage under Application Support, and copy-to-job for report image.
//

import Foundation
import CoreData
import AppKit

enum StormCatalogService {

    // MARK: - Directory

    /// Base directory for all storm catalog images: Application Support/.../storm_catalog_images
    static func stormCatalogImagesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "DesktopHomeInfoScraper"
        let dir = appSupport.appendingPathComponent(bundleId).appendingPathComponent("storm_catalog_images")
        return dir
    }

    /// Directory for a specific catalog storm's images: .../storm_catalog_images/<stormId>/
    static func stormImageDirectory(stormId: UUID) -> URL {
        stormCatalogImagesDirectory().appendingPathComponent(stormId.uuidString)
    }

    /// Full file URL for a catalog image (storm relationship gives stormId).
    static func fileURL(for image: CatalogStormImage) -> URL? {
        guard let storm = image.storm else { return nil }
        return stormImageDirectory(stormId: storm.id ?? UUID())
            .appendingPathComponent(image.filePath ?? "")
    }

    /// Load NSImage for a catalog image (for thumbnails and "Use this image").
    static func loadImage(for image: CatalogStormImage) -> NSImage? {
        guard let url = fileURL(for: image), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Directory for job custom hurricane images (same as NamedStormEditView).
    static func customHurricaneImagesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_hurricane_images")
    }

    // MARK: - Fetch

    static func fetchAllCatalogStorms(context: NSManagedObjectContext) -> [CatalogStorm] {
        let request: NSFetchRequest<CatalogStorm> = CatalogStorm.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CatalogStorm.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CatalogStorm.name, ascending: true)
        ]
        do {
            return try context.fetch(request)
        } catch {
            print("MYDEBUG → StormCatalogService fetchAllCatalogStorms failed: \(error.localizedDescription)")
            return []
        }
    }

    static func fetchCatalogStorm(byId id: UUID, context: NSManagedObjectContext) -> CatalogStorm? {
        let request: NSFetchRequest<CatalogStorm> = CatalogStorm.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Returns true if any catalog storm has the given name (trimmed, case-insensitive), optionally excluding one storm by id.
    static func catalogStormNameExists(_ name: String, excludingStormId: UUID?, context: NSManagedObjectContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let all = fetchAllCatalogStorms(context: context)
        let lower = trimmed.lowercased()
        return all.contains { storm in
            if let excludeId = excludingStormId, storm.id == excludeId { return false }
            return (storm.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower
        }
    }

    /// Ordered images for a storm (by sortOrder, then by id).
    static func orderedImages(for storm: CatalogStorm) -> [CatalogStormImage] {
        let set = storm.images as? Set<CatalogStormImage> ?? []
        return set.sorted { a, b in
            let orderA = a.sortOrder
            let orderB = b.sortOrder
            if orderA != orderB { return orderA < orderB }
            return (a.id ?? UUID()).uuidString < (b.id ?? UUID()).uuidString
        }
    }

    /// Primary image for a storm (isPrimary == true, or first in order).
    static func primaryImage(for storm: CatalogStorm) -> CatalogStormImage? {
        let ordered = orderedImages(for: storm)
        return ordered.first(where: { $0.isPrimary }) ?? ordered.first
    }

    // MARK: - Create / Update

    static func createCatalogStorm(
        name: String,
        stormDate: Date,
        defaultWeatherText: String?,
        defaultSourceText: String?,
        context: NSManagedObjectContext
    ) -> CatalogStorm? {
        let storm = CatalogStorm(context: context)
        storm.id = UUID()
        storm.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        storm.stormDate = stormDate
        storm.sortOrder = Int16(StormCatalogService.fetchAllCatalogStorms(context: context).count)
        storm.defaultWeatherText = defaultWeatherText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? defaultWeatherText : nil
        storm.defaultSourceText = defaultSourceText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? defaultSourceText : nil
        do {
            try context.save()
            return storm
        } catch {
            print("MYDEBUG → StormCatalogService createCatalogStorm failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func updateCatalogStorm(
        _ storm: CatalogStorm,
        name: String?,
        stormDate: Date?,
        defaultWeatherText: String?,
        defaultSourceText: String?,
        context: NSManagedObjectContext
    ) {
        if let n = name { storm.name = n.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let d = stormDate { storm.stormDate = d }
        storm.defaultWeatherText = defaultWeatherText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? defaultWeatherText : nil
        storm.defaultSourceText = defaultSourceText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? defaultSourceText : nil
        try? context.save()
    }

    /// Add an image to a catalog storm. Copies file from sourceURL into storm_catalog_images/<stormId>/<uuid>.jpg.
    static func addImage(
        to storm: CatalogStorm,
        sourceURL: URL,
        caption: String?,
        isPrimary: Bool,
        context: NSManagedObjectContext
    ) -> CatalogStormImage? {
        guard let stormId = storm.id else { return nil }
        let dir = stormImageDirectory(stormId: stormId)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("MYDEBUG → StormCatalogService addImage createDirectory failed: \(error.localizedDescription)")
            return nil
        }
        let ext = sourceURL.pathExtension.lowercased()
        let allowed = ["jpg", "jpeg", "png", "heic", "tiff", "bmp", "gif"]
        let suffix = allowed.contains(ext) ? ext : "jpg"
        let fileName = "\(UUID().uuidString).\(suffix)"
        let destURL = dir.appendingPathComponent(fileName)
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            print("MYDEBUG → StormCatalogService addImage copy failed: \(error.localizedDescription)")
            return nil
        }
        let image = CatalogStormImage(context: context)
        image.id = UUID()
        image.filePath = fileName
        image.caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? caption : nil
        image.storm = storm
        let existing = StormCatalogService.orderedImages(for: storm)
        image.sortOrder = Int16(existing.count)
        if isPrimary {
            existing.forEach { $0.isPrimary = false }
            image.isPrimary = true
        } else {
            image.isPrimary = existing.isEmpty
        }
        do {
            try context.save()
            return image
        } catch {
            print("MYDEBUG → StormCatalogService addImage save failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func setPrimaryImage(_ image: CatalogStormImage, context: NSManagedObjectContext) {
        guard let storm = image.storm else { return }
        StormCatalogService.orderedImages(for: storm).forEach { $0.isPrimary = ($0.id == image.id) }
        try? context.save()
    }

    static func removeImage(_ image: CatalogStormImage, context: NSManagedObjectContext) {
        if let url = StormCatalogService.fileURL(for: image) {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(image)
        try? context.save()
    }

    static func reorderImages(_ storm: CatalogStorm, orderedImages: [CatalogStormImage], context: NSManagedObjectContext) {
        for (idx, img) in orderedImages.enumerated() {
            img.sortOrder = Int16(idx)
        }
        try? context.save()
    }

    // MARK: - Delete storm

    static func deleteCatalogStorm(_ storm: CatalogStorm, context: NSManagedObjectContext) {
        let dir = stormImageDirectory(stormId: storm.id ?? UUID())
        try? FileManager.default.removeItem(at: dir)
        context.delete(storm)
        try? context.save()
    }

    // MARK: - Copy to job (for "Use this image" in Named Storm)

    /// Copies the catalog image file into custom_hurricane_images and sets job.customHurricaneImagePath.
    static func copyCatalogImageToJob(_ catalogImage: CatalogStormImage, job: Job, context: NSManagedObjectContext) {
        guard let sourceURL = StormCatalogService.fileURL(for: catalogImage),
              FileManager.default.fileExists(atPath: sourceURL.path),
              let imageData = try? Data(contentsOf: sourceURL),
              let nsImage = NSImage(data: imageData),
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("MYDEBUG → StormCatalogService copyCatalogImageToJob: failed to load or convert image")
            return
        }
        let jobId = (job.jobId ?? "").isEmpty ? UUID().uuidString : (job.jobId ?? UUID().uuidString)
        let destDir = customHurricaneImagesDirectory()
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let fileName = "\(jobId)_custom_hurricane.jpg"
            let destURL = destDir.appendingPathComponent(fileName)
            try jpegData.write(to: destURL)
            job.customHurricaneImagePath = fileName
            try context.save()
        } catch {
            print("MYDEBUG → StormCatalogService copyCatalogImageToJob write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Unified storm list for picker

    /// Item for the Named Storm picker: either a catalog storm, a known storm from storms.md, or "Other".
    enum StormPickerItem: Identifiable {
        case catalogStorm(CatalogStorm)
        case knownStorm(KnownStorm)
        case other

        var id: String {
            switch self {
            case .catalogStorm(let s): return "catalog:\(s.id?.uuidString ?? "")"
            case .knownStorm(let k): return "known:\(k.name)"
            case .other: return "other"
            }
        }

        var displayName: String {
            switch self {
            case .catalogStorm(let s): return s.name ?? ""
            case .knownStorm(let k): return k.name
            case .other: return "Other"
            }
        }

        var date: Date? {
            switch self {
            case .catalogStorm(let s): return s.stormDate
            case .knownStorm(let k): return k.date
            case .other: return nil
            }
        }

        var isCatalogStorm: Bool {
            if case .catalogStorm = self { return true }
            return false
        }

        var catalogStorm: CatalogStorm? {
            if case .catalogStorm(let s) = self { return s }
            return nil
        }
    }

    /// Combined list for the picker: catalog storms first, then known storms from storms.md, then Other.
    static func unifiedStormPickerItems(context: NSManagedObjectContext) -> [StormPickerItem] {
        var items: [StormPickerItem] = []
        let catalog = fetchAllCatalogStorms(context: context)
        for storm in catalog {
            let name = storm.name ?? ""
            if !name.isEmpty {
                items.append(.catalogStorm(storm))
            }
        }
        for known in StormHelpers.loadKnownStorms() {
            if !items.contains(where: { $0.displayName == known.name }) {
                items.append(.knownStorm(known))
            }
        }
        items.append(.other)
        return items
    }
}
