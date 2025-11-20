//
//  ScrapingManager.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import CoreData
import SwiftUI
import MapKit
import CoreLocation
import AppKit

@MainActor
class ScrapingManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentJob: Job?
    @Published var progress: Double = 0.0
    
    private var scrapingTask: Task<Void, Never>?
    private let scrapers: [PropertyScraper] = [
        // Commented out property appraiser scrapers - switching to Google Maps
        // EnhancedHillsboroughCountyScraper(),
        // FallbackHillsboroughCountyScraper(),
        // PinellasCountyScraper(),
        // PascoCountyScraper(),
        GoogleMapsAerialScraper()
    ]
    
    func startScraping(context: NSManagedObjectContext) {
        print("🔘 [ScrapingManager] startScraping() called")
        guard !isRunning else { 
            print("⚠️ [ScrapingManager] Already running, ignoring start request")
            return 
        }
        
        print("🚀 [ScrapingManager] Starting scraping process")
        isRunning = true
        progress = 0.0
        
        scrapingTask = Task {
            await performScraping(context: context)
        }
    }
    
    func stopScraping() {
        scrapingTask?.cancel()
        isRunning = false
        currentJob = nil
        progress = 0.0
    }
    
    private func performScraping(context: NSManagedObjectContext) async {
        print("📋 [ScrapingManager] Fetching queued jobs...")
        let fetchRequest: NSFetchRequest<Job> = Job.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "queued")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Job.createdAt, ascending: true)]
        
        do {
            let queuedJobs = try context.fetch(fetchRequest)
            print("📊 [ScrapingManager] Found \(queuedJobs.count) queued jobs")
            let totalJobs = queuedJobs.count
            
            guard totalJobs > 0 else {
                await MainActor.run {
                    isRunning = false
                }
                return
            }
            
            for (index, job) in queuedJobs.enumerated() {
                guard !Task.isCancelled else { break }
                
                await MainActor.run {
                    currentJob = job
                    job.status = "running"
                    job.updatedAt = Date()
                    progress = Double(index) / Double(totalJobs)
                }
                
                do {
                    try context.save()
                } catch {
                    print("Failed to save job status: \(error)")
                }
                
                // Perform scraping
                await scrapeJob(job: job, context: context)
                
                await MainActor.run {
                    progress = Double(index + 1) / Double(totalJobs)
                }
            }
            
            await MainActor.run {
                isRunning = false
                currentJob = nil
                progress = 1.0
            }
            
        } catch {
            print("Failed to fetch queued jobs: \(error)")
            await MainActor.run {
                isRunning = false
                currentJob = nil
            }
        }
    }
    
    private func scrapeJob(job: Job, context: NSManagedObjectContext) async {
        // Use cleaned address if available, fallback to original address
        let addressToUse = job.cleanedAddressLine1 ?? job.addressLine1 ?? ""
        let address = ScrapeParams(
            addressLine1: addressToUse,
            city: job.city ?? "",
            state: job.state ?? "",
            zip: job.zip
        )
        
        // Try each scraper until one succeeds
        for scraper in scrapers {
            guard !Task.isCancelled else { break }
            
            do {
                let result = try await scraper.scrapeProperty(params: address)
                
                await MainActor.run {
                    // Save the overhead image
                    if let imageData = result.imageBuffer {
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let imagesPath = documentsPath.appendingPathComponent("Images")
                        
                        // Create Images directory if it doesn't exist
                        try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
                        
                        let imageFileName = "\(job.jobId ?? UUID().uuidString)_overhead.jpg"
                        let imageURL = imagesPath.appendingPathComponent(imageFileName)
                        
                        do {
                            try imageData.write(to: imageURL)
                            job.overheadImagePath = imageURL.path
                            print("✅ [ScrapingManager] Saved overhead image: \(imageURL.path)")
                        } catch {
                            print("❌ [ScrapingManager] Failed to save overhead image: \(error)")
                        }
                    }
                    
                    job.sourceName = result.sourceName
                    job.sourceUrl = result.canonicalUrl
                    job.parcelId = result.parcelId
                    job.status = "completed"
                    job.updatedAt = Date()
                }
                
                // Generate and save wide view map
                await generateWideViewMap(for: job, context: context)
                
                do {
                    try context.save()
                    print("✅ [ScrapingManager] Successfully saved job \(job.jobId ?? "") as completed")
                } catch {
                    print("❌ [ScrapingManager] Failed to save job result: \(error)")
                }
                
                return // Success, exit the loop
                
            } catch {
                print("Scraper \(scraper.name) failed for job \(job.jobId ?? ""): \(error)")
                continue // Try next scraper
            }
        }
        
        // If all scrapers failed
        await MainActor.run {
            job.status = "failed"
            job.errorMessage = "All scrapers failed to find property data"
            job.updatedAt = Date()
        }
        
        do {
            try context.save()
            print("✅ [ScrapingManager] Successfully saved job \(job.jobId ?? "") as failed")
        } catch {
            print("❌ [ScrapingManager] Failed to save job failure: \(error)")
        }
    }
    
    private func generateWideViewMap(for job: Job, context: NSManagedObjectContext) async {
        // Build address string for geocoding
        // Use cleaned address if available, fallback to original address
        var addressParts: [String] = []
        let addressToUse = job.cleanedAddressLine1 ?? job.addressLine1 ?? ""
        if !addressToUse.isEmpty {
            addressParts.append(addressToUse)
        }
        if let city = job.city, !city.isEmpty {
            addressParts.append(city)
        }
        
        // Combine state and zip with a space, not comma
        var stateZip: [String] = []
        if let state = job.state, !state.isEmpty {
            stateZip.append(state)
        }
        if let zip = job.zip, !zip.isEmpty {
            stateZip.append(zip)
        }
        if !stateZip.isEmpty {
            addressParts.append(stateZip.joined(separator: " "))
        }
        
        let addressString = addressParts.joined(separator: ", ")
        
        guard !addressString.isEmpty else {
            print("⚠️ [ScrapingManager] Cannot generate map - empty address")
            return
        }
        
        // Geocode the address
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(addressString) { placemarks, error in
                if let error = error {
                    print("⚠️ [ScrapingManager] Geocoding failed for map: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    print("⚠️ [ScrapingManager] No location found for map: \(addressString)")
                    continuation.resume()
                    return
                }
                
                let coordinate = location.coordinate
                print("✅ [ScrapingManager] Geocoded for map: \(coordinate.latitude), \(coordinate.longitude)")
                
                // Generate map image showing Florida with property location
                Task { @MainActor in
                    let mapImage = await self.createWideViewMapImage(coordinate: coordinate, jobId: job.jobId ?? "job")
                    
                    if let mapImage = mapImage {
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let imagesPath = documentsPath.appendingPathComponent("Images")
                        
                        // Create Images directory if it doesn't exist
                        try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
                        
                        let mapFileName = "\(job.jobId ?? UUID().uuidString)_location_map.png"
                        let mapURL = imagesPath.appendingPathComponent(mapFileName)
                        
                        if let tiffData = mapImage.tiffRepresentation,
                           let bitmapImage = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                            do {
                                try pngData.write(to: mapURL)
                                print("✅ [ScrapingManager] Saved wide view map: \(mapURL.path)")
                            } catch {
                                print("❌ [ScrapingManager] Failed to save map: \(error)")
                            }
                        }
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func createWideViewMapImage(coordinate: CLLocationCoordinate2D, jobId: String) async -> NSImage? {
        // Florida approximate bounds for map region
        let floridaCenter = CLLocationCoordinate2D(latitude: 28.5, longitude: -82.0)
        let floridaSpan = MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 8.0)
        let region = MKCoordinateRegion(center: floridaCenter, span: floridaSpan)
        
        // Use MKMapSnapshotter for image export
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = NSSize(width: 800, height: 600)
        options.mapType = .standard
        
        return await withCheckedContinuation { continuation in
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start { snapshot, error in
                guard let snapshot = snapshot else {
                    print("⚠️ [ScrapingManager] Map snapshot failed")
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

// MARK: - Scraper Protocol

protocol PropertyScraper {
    var name: String { get }
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult
}

struct ScrapeParams {
    let addressLine1: String
    let city: String
    let state: String
    let zip: String?
}

struct ScrapeResult {
    let imageBuffer: Data?
    let sourceName: String
    let canonicalUrl: String
    let parcelId: String?
    let notes: String?
}

// MARK: - Hillsborough County Scraper

class HillsboroughCountyScraper: PropertyScraper {
    let name = "Hillsborough County Property Appraiser"
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        // This is a simplified implementation
        // In a real implementation, you would use Playwright or similar to navigate the website
        
        let searchUrl = "https://www.hcpafl.org/search/real-estate"
        
        // For now, we'll simulate the scraping process
        // In a real implementation, you would:
        // 1. Navigate to the search page
        // 2. Fill in the address form
        // 3. Submit the search
        // 4. Navigate to the property details
        // 5. Extract the overhead image
        // 6. Return the result
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For demonstration, we'll create a placeholder result
        // In reality, you would extract this from the website
        return ScrapeResult(
            imageBuffer: createPlaceholderImage(),
            sourceName: name,
            canonicalUrl: searchUrl,
            parcelId: "12345-678-90",
            notes: "Scraped from Hillsborough County Property Appraiser"
        )
    }
    
    private func createPlaceholderImage() -> Data? {
        // Create a simple placeholder image
        let size = NSSize(width: 400, height: 300)
        let image = NSImage(size: size)
        
        image.lockFocus()
        NSColor.lightGray.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Add some text
        let text = "Property Image\n(Placeholder)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.darkGray
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        
        // Convert to JPEG data
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}

// MARK: - Other County Scrapers (Placeholder implementations)

class PinellasCountyScraper: PropertyScraper {
    let name = "Pinellas County Property Appraiser"
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        // Placeholder implementation
        _ = params // Suppress unused parameter warning
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        throw ScrapingError.noDataFound
    }
}

class PascoCountyScraper: PropertyScraper {
    let name = "Pasco County Property Appraiser"
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        // Placeholder implementation
        _ = params // Suppress unused parameter warning
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        throw ScrapingError.noDataFound
    }
}

enum ScrapingError: LocalizedError {
    case noDataFound
    case networkError
    case parsingError
    case rateLimited
    case invalidURL
    case missingParameters
    
    var errorDescription: String? {
        switch self {
        case .noDataFound:
            return "No property data found"
        case .networkError:
            return "Network error occurred"
        case .parsingError:
            return "Failed to parse property data"
        case .rateLimited:
            return "Rate limited by the website"
        case .invalidURL:
            return "Invalid URL provided"
        case .missingParameters:
            return "Missing required parameters"
        }
    }
}
