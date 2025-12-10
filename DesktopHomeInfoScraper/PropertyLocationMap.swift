//
//  PropertyLocationMap.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 11/16/25.
//

import SwiftUI
import MapKit
import CoreLocation

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

struct PropertyLocationMap: View {
    let job: Job
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isGeocoding = false
    @State private var geocodingError: String?
    
    // Florida approximate bounds for map region
    // Center: ~28.5°N, 82.0°W
    // Span: ~6° latitude, 8° longitude to show most of Florida
    private let floridaCenter = CLLocationCoordinate2D(latitude: 28.5, longitude: -82.0)
    private let floridaSpan = MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 8.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Location Map")
                .font(.headline)
            
            if isGeocoding {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding property location...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
            } else if let error = geocodingError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("Could not find location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            } else if let coordinate = coordinate {
                MapView(
                    center: floridaCenter,
                    span: floridaSpan,
                    propertyCoordinate: coordinate,
                    propertyTitle: job.jobId ?? "Property"
                )
                .frame(height: 400)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                MapView(
                    center: floridaCenter,
                    span: floridaSpan,
                    propertyCoordinate: nil,
                    propertyTitle: nil
                )
                .frame(height: 400)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .onAppear {
            geocodeAddress()
        }
    }
    
    private func geocodeAddress() {
        guard coordinate == nil && !isGeocoding else { return }
        
        isGeocoding = true
        geocodingError = nil
        
        // Use formatAddress helper which handles cleaned address and proper formatting
        let addressString = formatAddress(job: job)
        
        print("🗺️ [PropertyLocationMap] Geocoding address: '\(addressString)' for job: \(job.jobId ?? "Unknown")")
        
        // If address is empty, skip geocoding
        if addressString.trimmingCharacters(in: .whitespaces).isEmpty || addressString == ",  " {
            print("⚠️ [PropertyLocationMap] Address is empty, skipping geocoding")
            isGeocoding = false
            geocodingError = "Address not available"
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(addressString) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
                
                if let error = error {
                    geocodingError = error.localizedDescription
                    print("⚠️ [PropertyLocationMap] Geocoding failed: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    geocodingError = "No location found for address"
                    print("⚠️ [PropertyLocationMap] No location found for address: \(addressString)")
                    return
                }
                
                coordinate = location.coordinate
                print("✅ [PropertyLocationMap] Geocoded address to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }
    
    // Function to export map as image
    func exportMapImage() -> NSImage? {
        guard let coordinate = coordinate else { return nil }
        
        let mapView = MKMapView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        mapView.mapType = .standard
        
        // Set region to show Florida with property
        let region = MKCoordinateRegion(
            center: floridaCenter,
            span: floridaSpan
        )
        mapView.setRegion(region, animated: false)
        
        // Add annotation for property
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = job.jobId ?? "Property"
        mapView.addAnnotation(annotation)
        
        // Wait a moment for map to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This is a simplified approach - in production you might want to use MKMapSnapshotter
        }
        
        // Use MKMapSnapshotter for better image export
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = NSSize(width: 800, height: 600)
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        var snapshotImage: NSImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else {
                semaphore.signal()
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
            snapshotImage = finalImage
            
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 10)
        return snapshotImage
    }
}

// MARK: - MapView (NSViewRepresentable wrapper for MKMapView)

struct MapView: NSViewRepresentable {
    let center: CLLocationCoordinate2D
    let span: MKCoordinateSpan
    let propertyCoordinate: CLLocationCoordinate2D?
    let propertyTitle: String?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsZoomControls = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Set region to show Florida
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
        
        // Add annotation if we have coordinates
        if let coordinate = propertyCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = propertyTitle ?? "Property"
            mapView.addAnnotation(annotation)
            
            // Select the annotation to show the title
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                mapView.selectAnnotation(annotation, animated: true)
            }
        }
        
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Update if needed
        if let coordinate = propertyCoordinate {
            // Remove existing annotations
            mapView.removeAnnotations(mapView.annotations)
            
            // Add property annotation
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = propertyTitle ?? "Property"
            mapView.addAnnotation(annotation)
            
            // Select the annotation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                mapView.selectAnnotation(annotation, animated: true)
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let job = Job(context: context)
    job.jobId = "E2025-05091"
    job.addressLine1 = "408 2nd Ave NW"
    job.city = "Largo"
    job.state = "FL"
    job.zip = "33770"
    
    return PropertyLocationMap(job: job)
        .padding()
        .frame(width: 600, height: 500)
}

