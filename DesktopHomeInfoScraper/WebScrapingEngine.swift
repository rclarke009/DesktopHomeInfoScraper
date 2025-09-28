//
//  WebScrapingEngine.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import WebKit
import SwiftUI

class WebScrapingEngine: NSObject, ObservableObject {
    private var webView: WKWebView
    private var completionHandler: ((Result<ScrapeResult, Error>) -> Void)?
    private var currentParams: ScrapeParams?
    
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Configure user agent to appear as a regular browser
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    func scrapeProperty(params: ScrapeParams, completion: @escaping (Result<ScrapeResult, Error>) -> Void) {
        self.currentParams = params
        self.completionHandler = completion
        
        // Start with the Hillsborough County Property Appraiser search page
        let searchURL = "https://www.hcpafl.org/search/real-estate"
        
        guard let url = URL(string: searchURL) else {
            completion(.failure(ScrapingError.invalidURL))
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func performSearch() {
        guard let params = currentParams else {
            completionHandler?(.failure(ScrapingError.missingParameters))
            return
        }
        
        // JavaScript to fill out the search form
        let searchScript = """
        (function() {
            // Wait for the page to load
            function waitForElement(selector, callback) {
                const element = document.querySelector(selector);
                if (element) {
                    callback(element);
                } else {
                    setTimeout(() => waitForElement(selector, callback), 100);
                }
            }
            
            // Fill out the address form
            waitForElement('input[name="address"]', function(addressInput) {
                addressInput.value = '\(params.addressLine1)';
                
                // Find and fill city
                const cityInput = document.querySelector('input[name="city"]');
                if (cityInput) {
                    cityInput.value = '\(params.city)';
                }
                
                // Find and fill state
                const stateInput = document.querySelector('input[name="state"]');
                if (stateInput) {
                    stateInput.value = '\(params.state)';
                }
                
                // Find and fill zip if provided
                if ('\(params.zip ?? "")' !== '') {
                    const zipInput = document.querySelector('input[name="zip"]');
                    if (zipInput) {
                        zipInput.value = '\(params.zip ?? "")';
                    }
                }
                
                // Submit the form
                const submitButton = document.querySelector('button[type="submit"], input[type="submit"]');
                if (submitButton) {
                    submitButton.click();
                } else {
                    // Try to find a form and submit it
                    const form = document.querySelector('form');
                    if (form) {
                        form.submit();
                    }
                }
            });
        })();
        """
        
        webView.evaluateJavaScript(searchScript) { [weak self] result, error in
            if let error = error {
                self?.completionHandler?(.failure(error))
            }
        }
    }
    
    private func extractPropertyData() {
        let extractionScript = """
        (function() {
            // Look for property information on the results page
            const propertyData = {
                parcelId: null,
                imageUrl: null,
                propertyUrl: window.location.href
            };
            
            // Try to find parcel ID
            const parcelElements = document.querySelectorAll('*');
            for (let element of parcelElements) {
                const text = element.textContent || '';
                if (text.match(/\\d{2}-\\d{3}-\\d{3}-\\d{3}/)) {
                    propertyData.parcelId = text.match(/\\d{2}-\\d{3}-\\d{3}-\\d{3}/)[0];
                    break;
                }
            }
            
            // Look for property images
            const images = document.querySelectorAll('img');
            for (let img of images) {
                const src = img.src || '';
                if (src.includes('aerial') || src.includes('satellite') || src.includes('overhead') || 
                    src.includes('property') || src.includes('building')) {
                    propertyData.imageUrl = src;
                    break;
                }
            }
            
            // If no specific property image found, look for any property-related image
            if (!propertyData.imageUrl) {
                for (let img of images) {
                    const src = img.src || '';
                    if (src.includes('jpg') || src.includes('jpeg') || src.includes('png')) {
                        propertyData.imageUrl = src;
                        break;
                    }
                }
            }
            
            return propertyData;
        })();
        """
        
        webView.evaluateJavaScript(extractionScript) { [weak self] result, error in
            if let error = error {
                self?.completionHandler?(.failure(error))
                return
            }
            
            guard let data = result as? [String: Any] else {
                self?.completionHandler?(.failure(ScrapingError.noDataFound))
                return
            }
            
            self?.processPropertyData(data)
        }
    }
    
    private func processPropertyData(_ data: [String: Any]) {
        guard let params = currentParams else {
            completionHandler?(.failure(ScrapingError.missingParameters))
            return
        }
        
        let parcelId = data["parcelId"] as? String
        let imageUrlString = data["imageUrl"] as? String
        let propertyUrl = data["propertyUrl"] as? String ?? ""
        
        // If we found an image URL, download it
        if let imageUrlString = imageUrlString, let imageUrl = URL(string: imageUrlString) {
            downloadImage(from: imageUrl) { [weak self] imageData in
                let result = ScrapeResult(
                    imageBuffer: imageData,
                    sourceName: "Hillsborough County Property Appraiser",
                    canonicalUrl: propertyUrl,
                    parcelId: parcelId,
                    notes: "Scraped from HCPA website"
                )
                self?.completionHandler?(.success(result))
            }
        } else {
            // No image found, but we might have other data
            let result = ScrapeResult(
                imageBuffer: nil,
                sourceName: "Hillsborough County Property Appraiser",
                canonicalUrl: propertyUrl,
                parcelId: parcelId,
                notes: "Property found but no image available"
            )
            completionHandler?(.success(result))
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (Data?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to download image: \(error)")
                    completion(nil)
                } else {
                    completion(data)
                }
            }
        }
        task.resume()
    }
}

// MARK: - WKNavigationDelegate

extension WebScrapingEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a moment for the page to fully load, then perform search
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performSearch()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completionHandler?(.failure(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completionHandler?(.failure(error))
    }
}

// MARK: - WKUIDelegate

extension WebScrapingEngine: WKUIDelegate {
    // Handle any UI delegate methods if needed
}

// MARK: - Enhanced Hillsborough County Scraper

class EnhancedHillsboroughCountyScraper: PropertyScraper {
    let name = "Hillsborough County Property Appraiser (Enhanced)"
    private let webEngine = WebScrapingEngine()
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        return try await withCheckedThrowingContinuation { continuation in
            webEngine.scrapeProperty(params: params) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Fallback Scraper for when web scraping fails

class FallbackHillsboroughCountyScraper: PropertyScraper {
    let name = "Hillsborough County Property Appraiser (Fallback)"
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        // Simulate a delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For demonstration, create a placeholder image with property information
        let imageData = createPropertyPlaceholderImage(for: params)
        
        return ScrapeResult(
            imageBuffer: imageData,
            sourceName: name,
            canonicalUrl: "https://www.hcpafl.org/search/real-estate",
            parcelId: generateParcelId(for: params),
            notes: "Fallback scraper - placeholder image generated"
        )
    }
    
    private func createPropertyPlaceholderImage(for params: ScrapeParams) -> Data? {
        let size = NSSize(width: 600, height: 400)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Background
        NSColor.systemBlue.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Border
        NSColor.systemBlue.setStroke()
        let borderRect = NSRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let borderPath = NSBezierPath(rect: borderRect)
        borderPath.lineWidth = 2
        borderPath.stroke()
        
        // Property information
        let propertyInfo = """
        Property Information
        
        Address: \(params.addressLine1)
        City: \(params.city)
        State: \(params.state)
        \(params.zip != nil ? "ZIP: \(params.zip!)" : "")
        
        Source: Hillsborough County Property Appraiser
        Status: Placeholder Image
        """
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let textSize = propertyInfo.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        propertyInfo.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        
        // Convert to JPEG data
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
    
    private func generateParcelId(for params: ScrapeParams) -> String {
        // Generate a mock parcel ID based on the address
        let addressHash = abs(params.addressLine1.hashValue)
        let cityHash = abs(params.city.hashValue)
        let stateHash = abs(params.state.hashValue)
        
        let parcelNumber = (addressHash + cityHash + stateHash) % 1000000
        return String(format: "%02d-%03d-%03d-%03d", 
                     stateHash % 100,
                     cityHash % 1000,
                     addressHash % 1000,
                     parcelNumber % 1000)
    }
}
