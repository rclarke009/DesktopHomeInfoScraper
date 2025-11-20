//
//  WebScrapingEngine.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import Foundation
import WebKit
import SwiftUI
import CoreLocation

class WebScrapingEngine: NSObject, ObservableObject {
    private var webView: WKWebView
    private var completionHandler: ((Result<ScrapeResult, Error>) -> Void)?
    private var currentParams: ScrapeParams?
    private var hasCompleted = false
    private var isSearching = false
    
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
        print("🔍 [WebScrapingEngine] Starting scrape for: \(params.addressLine1), \(params.city), \(params.state)")
        self.currentParams = params
        self.completionHandler = completion
        self.hasCompleted = false
        self.isSearching = false
        
        // Start with the Hillsborough County Property Appraiser search page
        let searchURL = "https://www.hcpafl.org/search/real-estate"
        print("🌐 [WebScrapingEngine] Loading URL: \(searchURL)")
        
        guard let url = URL(string: searchURL) else {
            print("❌ [WebScrapingEngine] Invalid URL: \(searchURL)")
            completion(.failure(ScrapingError.invalidURL))
            return
        }
        
        let request = URLRequest(url: url)
        
        // Ensure WebView operations happen on the main thread
        DispatchQueue.main.async { [weak self] in
            print("📱 [WebScrapingEngine] Loading WebView on main thread")
            self?.webView.load(request)
        }
    }
    
    // MARK: - Google Maps Aerial Scraping
    
    func scrapeGoogleMapsAerial(params: ScrapeParams, completionHandler: @escaping (Result<ScrapeResult, Error>) -> Void) {
        print("🗺️ [WebScrapingEngine] Starting Google Maps aerial scrape for: \(params.addressLine1), \(params.city), \(params.state)")
        
        self.completionHandler = completionHandler
        self.hasCompleted = false
        self.isSearching = false
        self.currentParams = params  // Set the current parameters
        
        // Build full address string
        var addressParts: [String] = []
        if !params.addressLine1.isEmpty {
            addressParts.append(params.addressLine1)
        }
        if !params.city.isEmpty {
            addressParts.append(params.city)
        }
        if !params.state.isEmpty {
            addressParts.append(params.state)
        }
        if let zip = params.zip, !zip.isEmpty {
            addressParts.append(zip)
        }
        
        let fullAddress = addressParts.joined(separator: ", ")
        
        guard !fullAddress.isEmpty else {
            print("❌ [WebScrapingEngine] Empty address provided")
            completeWithResult(.failure(ScrapingError.missingParameters))
            return
        }
        
        print("🗺️ [WebScrapingEngine] Full address: \(fullAddress)")
        
        // First, geocode the address to get coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(fullAddress) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [WebScrapingEngine] Geocoding failed: \(error.localizedDescription)")
                // Fall back to using address string directly
                self.downloadStaticMapImage(address: fullAddress, completionHandler: completionHandler)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("⚠️ [WebScrapingEngine] No location found, using address string")
                // Fall back to using address string directly
                self.downloadStaticMapImage(address: fullAddress, completionHandler: completionHandler)
                return
            }
            
            let coordinate = location.coordinate
            print("✅ [WebScrapingEngine] Geocoded to: \(coordinate.latitude), \(coordinate.longitude)")
            
            // Use coordinates for more reliable Static Maps API call
            self.downloadStaticMapImage(coordinate: coordinate, address: fullAddress, completionHandler: completionHandler)
        }
    }
    
    private func downloadStaticMapImage(coordinate: CLLocationCoordinate2D? = nil, address: String, completionHandler: @escaping (Result<ScrapeResult, Error>) -> Void) {
        // Construct Static Maps API URL for satellite imagery
        let apiKey = "AIzaSyBJqaMMXkcJTT2Z37Ye9NNCGlXqXyEJ9Uc"
        
        var staticMapsURL: String
        if let coord = coordinate {
            // Use coordinates (more reliable)
            staticMapsURL = "https://maps.googleapis.com/maps/api/staticmap?center=\(coord.latitude),\(coord.longitude)&zoom=21&size=800x600&maptype=satellite&format=png"
        } else {
            // Fall back to address string
            let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            staticMapsURL = "https://maps.googleapis.com/maps/api/staticmap?center=\(encodedAddress)&zoom=21&size=800x600&maptype=satellite&format=png"
        }
        
        if !apiKey.isEmpty {
            staticMapsURL += "&key=\(apiKey)"
        } else {
            print("⚠️ [WebScrapingEngine] No Google Maps API key provided - requests may fail or return limited data")
        }
        
        print("🗺️ [WebScrapingEngine] Using Google Static Maps API: \(staticMapsURL)")
        
        guard let url = URL(string: staticMapsURL) else {
            completeWithResult(.failure(ScrapingError.invalidURL))
            return
        }
        
        // Download the image directly instead of using WebView
        downloadImage(from: url) { [weak self] imageData in
            print("🗺️ [WebScrapingEngine] Static Maps API download completed, data size: \(imageData?.count ?? 0) bytes")
            
            // Check if we got an error response (usually small error images)
            if let imageData = imageData {
                // If the image is very small, it's likely an error message
                if imageData.count < 5000 {
                    print("⚠️ [WebScrapingEngine] Static Maps API returned small response (\(imageData.count) bytes) - likely API key required or error")
                    let result = ScrapeResult(
                        imageBuffer: nil,
                        sourceName: "Google Maps Satellite (Static API)",
                        canonicalUrl: staticMapsURL,
                        parcelId: nil,
                        notes: "Google Static Maps API requires API key or returned error (size: \(imageData.count) bytes)"
                    )
                    self?.completeWithResult(.success(result))
                    return
                }
                
                // Success - we got a reasonable sized image
                let result = ScrapeResult(
                    imageBuffer: imageData,
                    sourceName: "Google Maps Satellite (Static API)",
                    canonicalUrl: staticMapsURL,
                    parcelId: nil,
                    notes: "Aerial view from Google Static Maps API"
                )
                print("🎉 [WebScrapingEngine] Google Static Maps API scraping completed successfully (\(imageData.count) bytes)")
                self?.completeWithResult(.success(result))
            } else {
                let result = ScrapeResult(
                    imageBuffer: nil,
                    sourceName: "Google Maps Satellite (Static API)",
                    canonicalUrl: staticMapsURL,
                    parcelId: nil,
                    notes: "Google Static Maps API request failed - likely requires API key"
                )
                print("⚠️ [WebScrapingEngine] Google Static Maps API request failed - no data returned")
                self?.completeWithResult(.success(result))
            }
        }
    }
    
    private func completeWithResult(_ result: Result<ScrapeResult, Error>) {
        guard !hasCompleted else {
            print("⚠️ [WebScrapingEngine] Attempted to complete operation that already finished, ignoring")
            return
        }
        hasCompleted = true
        isSearching = false // Reset searching flag
        print("🏁 [WebScrapingEngine] Completing operation with result: \(result)")
        completionHandler?(result)
        completionHandler = nil // Clear the handler to prevent further calls
    }
    
    private func performSearch() {
        print("🔎 [WebScrapingEngine] performSearch() called")
        
        // Set searching flag to prevent multiple concurrent searches
        guard !isSearching else {
            print("⚠️ [WebScrapingEngine] Search already in progress, ignoring")
            return
        }
        isSearching = true
        
        guard let params = currentParams else {
            print("❌ [WebScrapingEngine] Missing parameters")
            isSearching = false // Reset searching flag on error
            completeWithResult(.failure(ScrapingError.missingParameters))
            return
        }
        print("📝 [WebScrapingEngine] Search params: \(params.addressLine1), \(params.city), \(params.state)")
        
        // JavaScript to fill out the search form
        let searchScript = """
        (function() {
            console.log('Starting property search for: \(params.addressLine1), \(params.city), \(params.state)');
            console.log('Current URL:', window.location.href);
            
            // Wait for the page to load
            function waitForElement(selector, callback, maxAttempts = 50) {
                const element = document.querySelector(selector);
                if (element) {
                    callback(element);
                } else if (maxAttempts > 0) {
                    setTimeout(() => waitForElement(selector, callback, maxAttempts - 1), 100);
                } else {
                    console.log('Element not found after timeout:', selector);
                }
            }
            
            // Try multiple possible selectors for address input
            const addressSelectors = [
                'input[name="address"]',
                'input[name="street"]', 
                'input[name="streetAddress"]',
                'input[placeholder*="address" i]',
                'input[placeholder*="street" i]',
                '#address',
                '#street'
            ];
            
            let addressFound = false;
            
            for (let selector of addressSelectors) {
                const addressInput = document.querySelector(selector);
                if (addressInput) {
                    console.log('Found address input with selector:', selector);
                    addressInput.value = '\(params.addressLine1)';
                    addressFound = true;
                    break;
                }
            }
            
            if (!addressFound) {
                console.log('No address input found, trying to find any text input...');
                const textInputs = document.querySelectorAll('input[type="text"]');
                if (textInputs.length > 0) {
                    console.log('Found', textInputs.length, 'text inputs, using the first one');
                    textInputs[0].value = '\(params.addressLine1)';
                    addressFound = true;
                }
            }
            
            if (addressFound) {
                // Try to find and fill city
                const citySelectors = ['input[name="city"]', 'input[placeholder*="city" i]', '#city'];
                for (let selector of citySelectors) {
                    const cityInput = document.querySelector(selector);
                    if (cityInput) {
                        console.log('Found city input with selector:', selector);
                        cityInput.value = '\(params.city)';
                        break;
                    }
                }
                
                // Try to find and fill state
                const stateSelectors = ['input[name="state"]', 'select[name="state"]', 'input[placeholder*="state" i]', '#state'];
                for (let selector of stateSelectors) {
                    const stateInput = document.querySelector(selector);
                    if (stateInput) {
                        console.log('Found state input with selector:', selector);
                        stateInput.value = '\(params.state)';
                        break;
                    }
                }
                
                // Try to submit the form
                console.log('Looking for submit button...');
                const submitSelectors = [
                    'button[type="submit"]',
                    'input[type="submit"]',
                    '.btn-primary',
                    '.search-btn',
                    'button.btn',
                    'input.btn'
                ];
                
                let submitted = false;
                for (let selector of submitSelectors) {
                    const submitButton = document.querySelector(selector);
                    if (submitButton) {
                        console.log('Found submit button with selector:', selector);
                        submitButton.click();
                        submitted = true;
                        break;
                    }
                }
                
                // If no standard selectors work, try to find buttons by text content
                if (!submitted) {
                    console.log('Trying to find buttons by text content...');
                    const allButtons = document.querySelectorAll('button, input[type="button"], input[type="submit"]');
                    for (let button of allButtons) {
                        const buttonText = (button.textContent || button.value || '').toLowerCase();
                        if (buttonText.includes('search') || buttonText.includes('submit') || buttonText.includes('go')) {
                            console.log('Found button by text content:', buttonText);
                            button.click();
                            submitted = true;
                            break;
                        }
                    }
                }
                
                if (!submitted) {
                    console.log('No submit button found, trying form submit...');
                    const forms = document.querySelectorAll('form');
                    if (forms.length > 0) {
                        console.log('Found', forms.length, 'forms, submitting the first one');
                        forms[0].submit();
                    } else {
                        console.log('No forms found on page');
                    }
                }
            } else {
                console.log('Could not find any address input field');
            }
        })();
        """
        
        DispatchQueue.main.async { [weak self] in
            print("📜 [WebScrapingEngine] Executing search JavaScript")
            self?.webView.evaluateJavaScript(searchScript) { [weak self] result, error in
                if let error = error {
                    print("❌ [WebScrapingEngine] JavaScript execution failed: \(error.localizedDescription)")
                    self?.completeWithResult(.failure(error))
                } else {
                    print("✅ [WebScrapingEngine] Search JavaScript executed successfully")
                    // After search is submitted, wait a moment then extract data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        print("📊 [WebScrapingEngine] Starting data extraction after 3 second delay")
                        self?.extractPropertyData()
                    }
                }
            }
        }
    }
    
    private func performGoogleMapsExtraction() {
        print("🗺️ [WebScrapingEngine] performGoogleMapsExtraction() called")
        
        guard currentParams != nil else {
            print("❌ [WebScrapingEngine] Missing parameters for Google Maps extraction")
            completeWithResult(.failure(ScrapingError.missingParameters))
            return
        }
        
        let extractionScript = """
        (function() {
            console.log('🗺️ Starting Google Maps aerial image extraction...');
            
            // Try to find and extract the satellite/aerial imagery
            const propertyData = {
                imageUrl: null,
                propertyUrl: window.location.href,
                sourceName: 'Google Maps Satellite'
            };
            
            // Method 1: Look for Google Maps tile images (most reliable)
            const tileImages = document.querySelectorAll('img[src*="maps.googleapis.com"], img[src*="mt1.google.com"], img[src*="mt0.google.com"], img[src*="khms.googleapis.com"], img[src*="maps/vt"]');
            console.log('🗺️ Found', tileImages.length, 'map tile images');
            
            if (tileImages.length > 0) {
                // Get the largest tile that looks like satellite imagery
                let bestTile = null;
                let maxSize = 0;
                
                for (let img of tileImages) {
                    const src = img.src || '';
                    const size = img.naturalWidth * img.naturalHeight;
                    
                    console.log('🗺️ Checking tile:', src.substring(0, 100) + '...', 'size:', size);
                    
                    // Look for satellite tiles (they usually contain specific patterns)
                    // Also check for tiles that are reasonably sized
                    if (size > maxSize && size > 10000 && // Must be reasonably large
                        (src.includes('satellite') || src.includes('sat') || 
                         src.includes('aerial') || src.includes('hybrid') ||
                         (!src.includes('roadmap') && !src.includes('terrain') && 
                          !src.includes('labels') && !src.includes('style')))) {
                        maxSize = size;
                        bestTile = img;
                    }
                }
                
                if (bestTile) {
                    propertyData.imageUrl = bestTile.src;
                    console.log('🗺️ Selected best satellite tile:', bestTile.src.substring(0, 100) + '...');
                    return propertyData;
                }
            }
            
            // Method 2: Try to find any Google Maps imagery
            const allImages = document.querySelectorAll('img');
            console.log('🗺️ Checking', allImages.length, 'total images for Google Maps content');
            
            for (let img of allImages) {
                const src = img.src || '';
                const alt = (img.alt || '').toLowerCase();
                
                // Look for Google Maps images
                if (src.includes('maps.googleapis.com') || src.includes('google.com/maps') ||
                    src.includes('mt0.google.com') || src.includes('mt1.google.com') ||
                    src.includes('khms.googleapis.com')) {
                    
                    // Must be reasonably sized
                    if (img.naturalWidth > 100 && img.naturalHeight > 100) {
                        propertyData.imageUrl = src;
                        console.log('🗺️ Found Google Maps image:', src);
                        return propertyData;
                    }
                }
            }
            
            // Method 3: Try to construct a satellite tile URL based on current view
            console.log('🗺️ Attempting to construct satellite tile URL from current map view');
            try {
                // Try to get map center and zoom from URL or page
                const urlParams = new URLSearchParams(window.location.search);
                const center = urlParams.get('center') || urlParams.get('q');
                const zoom = urlParams.get('zoom') || '20';
                
                if (center) {
                    // Try to construct a satellite tile URL
                    const encodedCenter = encodeURIComponent(center);
                    const satelliteTileUrl = `https://maps.googleapis.com/maps/api/staticmap?center=${encodedCenter}&zoom=${zoom}&size=800x600&maptype=satellite&format=png`;
                    console.log('🗺️ Constructed satellite tile URL:', satelliteTileUrl.substring(0, 100) + '...');
                    propertyData.imageUrl = satelliteTileUrl;
                    return propertyData;
                }
            } catch (e) {
                console.log('🗺️ Could not construct satellite tile URL:', e.message);
            }
            
            // Method 4: Try canvas extraction as last resort
            const canvas = document.querySelector('canvas');
            if (canvas) {
                console.log('🗺️ Found map canvas, attempting extraction');
                try {
                    const dataURL = canvas.toDataURL('image/png', 0.8);
                    if (dataURL && dataURL.length > 1000) { // Require larger image
                        propertyData.imageUrl = dataURL;
                        console.log('🗺️ Extracted canvas as data URL, size:', dataURL.length);
                        return propertyData;
                    }
                } catch (e) {
                    console.log('🗺️ Could not extract canvas data:', e.message);
                }
            }
            
            console.log('🗺️ No suitable satellite imagery found');
            return propertyData;
        })();
        """
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(extractionScript) { [weak self] result, error in
                if let error = error {
                    print("❌ [WebScrapingEngine] Google Maps JavaScript execution failed: \(error.localizedDescription)")
                    self?.completeWithResult(.failure(error))
                    return
                }
                
                print("✅ [WebScrapingEngine] Google Maps JavaScript executed successfully")
                print("📋 [WebScrapingEngine] Raw result: \(String(describing: result))")
                
                if let resultDict = result as? [String: Any] {
                    self?.processGoogleMapsData(resultDict)
                } else {
                    print("❌ [WebScrapingEngine] Invalid result format from Google Maps extraction")
                    self?.completeWithResult(.failure(ScrapingError.parsingError))
                }
            }
        }
    }
    
    private func extractPropertyData() {
        print("📊 [WebScrapingEngine] extractPropertyData() called")
        
        // Only extract data if we're still searching and haven't completed
        guard isSearching && !hasCompleted else {
            print("⚠️ [WebScrapingEngine] Skipping data extraction - not searching (\(isSearching)) or completed (\(hasCompleted))")
            return
        }
        
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
            
            // Look for actual property aerial/satellite images
            const images = document.querySelectorAll('img');
            console.log('Found', images.length, 'images on page');
            
            // First, exclude social media and UI elements
            const excludedKeywords = ['social', 'icon', 'logo', 'facebook', 'twitter', 'youtube', 'instagram', 'linkedin', 'footer', 'header', 'nav'];
            
            for (let img of images) {
                const src = img.src || '';
                const alt = (img.alt || '').toLowerCase();
                const className = (img.className || '').toLowerCase();
                
                console.log('Checking image:', src, 'alt:', alt, 'class:', className);
                
                // Skip social media and UI images
                let isExcluded = false;
                for (let keyword of excludedKeywords) {
                    if (src.toLowerCase().includes(keyword) || alt.includes(keyword) || className.includes(keyword)) {
                        console.log('Excluding image due to keyword:', keyword);
                        isExcluded = true;
                        break;
                    }
                }
                
                if (isExcluded) continue;
                
                // Look for actual property/aerial images
                const propertyKeywords = ['aerial', 'satellite', 'overhead', 'ortho', 'imagery', 'photo', 'image', 'property', 'parcel'];
                for (let keyword of propertyKeywords) {
                    if (src.toLowerCase().includes(keyword) || alt.includes(keyword) || className.includes(keyword)) {
                        // Additional check: image should be reasonably sized (not tiny icons)
                        if (img.naturalWidth && img.naturalHeight && 
                            img.naturalWidth > 100 && img.naturalHeight > 100 &&
                            img.naturalWidth < 10000 && img.naturalHeight < 10000) {
                            propertyData.imageUrl = src;
                            console.log('Found property image:', src);
                            break;
                        }
                    }
                }
                
                if (propertyData.imageUrl) break;
            }
            
            // If still no property image found, look for any reasonable-sized image that's not obviously UI
            if (!propertyData.imageUrl) {
                console.log('No specific property image found, looking for any reasonable image...');
                for (let img of images) {
                    const src = img.src || '';
                    const alt = (img.alt || '').toLowerCase();
                    
                    // Skip obvious UI elements
                    if (src.includes('.svg') || src.includes('icon') || src.includes('logo') || 
                        src.includes('social') || src.includes('facebook') || src.includes('twitter')) {
                        continue;
                    }
                    
                    // Must be a reasonable size and have image extension
                    if ((src.includes('.jpg') || src.includes('.jpeg') || src.includes('.png') || src.includes('.gif')) &&
                        img.naturalWidth && img.naturalHeight &&
                        img.naturalWidth > 200 && img.naturalHeight > 200 &&
                        img.naturalWidth < 10000 && img.naturalHeight < 10000) {
                        propertyData.imageUrl = src;
                        console.log('Found fallback image:', src);
                        break;
                    }
                }
            }
            
            return propertyData;
        })();
        """
        
        DispatchQueue.main.async { [weak self] in
            print("📜 [WebScrapingEngine] Executing extraction JavaScript")
            self?.webView.evaluateJavaScript(extractionScript) { [weak self] result, error in
                if let error = error {
                    print("❌ [WebScrapingEngine] Extraction JavaScript failed: \(error.localizedDescription)")
                    self?.completeWithResult(.failure(error))
                    return
                }
                
                print("✅ [WebScrapingEngine] Extraction JavaScript executed successfully")
                print("📋 [WebScrapingEngine] Raw result: \(String(describing: result))")
                
                guard let data = result as? [String: Any] else {
                    print("❌ [WebScrapingEngine] No data found in extraction result")
                    self?.completeWithResult(.failure(ScrapingError.noDataFound))
                    return
                }
                
                print("✅ [WebScrapingEngine] Processing extracted data: \(data)")
                self?.processPropertyData(data)
            }
        }
    }
    
    private func processPropertyData(_ data: [String: Any]) {
        print("🔄 [WebScrapingEngine] processPropertyData() called with: \(data)")
        guard let params = currentParams else {
            print("❌ [WebScrapingEngine] Missing parameters in processPropertyData")
            completeWithResult(.failure(ScrapingError.missingParameters))
            return
        }
        
        let parcelId = data["parcelId"] as? String
        let imageUrlString = data["imageUrl"] as? String
        let propertyUrl = data["propertyUrl"] as? String ?? ""
        
        print("📋 [WebScrapingEngine] Extracted data - ParcelID: \(parcelId ?? "none"), ImageURL: \(imageUrlString ?? "none"), PropertyURL: \(propertyUrl)")
        
        // If we found an image URL, download it
        if let imageUrlString = imageUrlString, let imageUrl = URL(string: imageUrlString) {
            print("🖼️ [WebScrapingEngine] Found image URL, downloading: \(imageUrlString)")
            downloadImage(from: imageUrl) { [weak self] imageData in
                print("✅ [WebScrapingEngine] Image download completed, data size: \(imageData?.count ?? 0) bytes")
                let result = ScrapeResult(
                    imageBuffer: imageData,
                    sourceName: "Hillsborough County Property Appraiser",
                    canonicalUrl: propertyUrl,
                    parcelId: parcelId,
                    notes: "Scraped from HCPA website"
                )
                print("🎉 [WebScrapingEngine] Scraping completed successfully with image")
                self?.completeWithResult(.success(result))
            }
        } else {
            // No image found, but we might have other data
            print("⚠️ [WebScrapingEngine] No image URL found, creating result without image")
            let result = ScrapeResult(
                imageBuffer: nil,
                sourceName: "Hillsborough County Property Appraiser",
                canonicalUrl: propertyUrl,
                parcelId: parcelId,
                notes: "Property found but no image available"
            )
            print("🎉 [WebScrapingEngine] Scraping completed successfully without image")
            completeWithResult(.success(result))
        }
    }
    
    private func processGoogleMapsData(_ data: [String: Any]) {
        print("🗺️ [WebScrapingEngine] processGoogleMapsData() called with: \(data)")
        guard currentParams != nil else {
            print("❌ [WebScrapingEngine] Missing parameters in processGoogleMapsData")
            completeWithResult(.failure(ScrapingError.missingParameters))
            return
        }
        
        let imageUrlString = data["imageUrl"] as? String
        let propertyUrl = data["propertyUrl"] as? String ?? ""
        let sourceName = data["sourceName"] as? String ?? "Google Maps Satellite"
        
        print("🗺️ [WebScrapingEngine] Google Maps data - ImageURL: \(imageUrlString ?? "none"), PropertyURL: \(propertyUrl)")
        
        // If we found an image URL, download it
        if let imageUrlString = imageUrlString {
            print("🖼️ [WebScrapingEngine] Found Google Maps image URL: \(imageUrlString)")
            
            // Check if it's a data URL (canvas export)
            if imageUrlString.hasPrefix("data:image/") {
                print("🗺️ [WebScrapingEngine] Processing data URL image, length: \(imageUrlString.count)")
                if let dataURL = URL(string: imageUrlString),
                   let data = try? Data(contentsOf: dataURL) {
                    
                    print("🗺️ [WebScrapingEngine] Data URL parsed successfully, data size: \(data.count) bytes")
                    
                    // Check if the image is too small (likely a placeholder)
                    if data.count < 500 { // Less than 500 bytes is probably too small
                        print("⚠️ [WebScrapingEngine] Data URL image too small (\(data.count) bytes), treating as no image")
                        let result = ScrapeResult(
                            imageBuffer: nil,
                            sourceName: sourceName,
                            canonicalUrl: propertyUrl,
                            parcelId: nil,
                            notes: "Google Maps loaded but satellite imagery could not be extracted (image too small: \(data.count) bytes)"
                        )
                        print("🎉 [WebScrapingEngine] Google Maps scraping completed without usable image")
                        completeWithResult(.success(result))
                        return
                    }
                    
                    let result = ScrapeResult(
                        imageBuffer: data,
                        sourceName: sourceName,
                        canonicalUrl: propertyUrl,
                        parcelId: nil,
                        notes: "Aerial view from Google Maps satellite imagery"
                    )
                    print("🎉 [WebScrapingEngine] Google Maps scraping completed successfully with canvas image (\(data.count) bytes)")
                    completeWithResult(.success(result))
                    return
                } else {
                    print("❌ [WebScrapingEngine] Failed to parse data URL or extract data")
                }
            } else if let imageUrl = URL(string: imageUrlString) {
                // Regular image URL
                downloadImage(from: imageUrl) { [weak self] imageData in
                    print("✅ [WebScrapingEngine] Google Maps image download completed, data size: \(imageData?.count ?? 0) bytes")
                    
                    // Check if the downloaded image is too small (likely an error/placeholder)
                    if let imageData = imageData, imageData.count < 1000 { // Less than 1KB is probably too small
                        print("⚠️ [WebScrapingEngine] Downloaded tile image too small (\(imageData.count) bytes), treating as no image")
                        let result = ScrapeResult(
                            imageBuffer: nil,
                            sourceName: sourceName,
                            canonicalUrl: propertyUrl,
                            parcelId: nil,
                            notes: "Google Maps tile downloaded but too small (\(imageData.count) bytes) - likely error/placeholder"
                        )
                        print("🎉 [WebScrapingEngine] Google Maps scraping completed without usable tile image")
                        self?.completeWithResult(.success(result))
                        return
                    }
                    
                    let result = ScrapeResult(
                        imageBuffer: imageData,
                        sourceName: sourceName,
                        canonicalUrl: propertyUrl,
                        parcelId: nil,
                        notes: "Aerial view from Google Maps satellite imagery"
                    )
                    print("🎉 [WebScrapingEngine] Google Maps scraping completed successfully with tile image (\(imageData?.count ?? 0) bytes)")
                    self?.completeWithResult(.success(result))
                }
                return
            }
        }
        
        // No image found
        print("⚠️ [WebScrapingEngine] No Google Maps image found, creating result without image")
        let result = ScrapeResult(
            imageBuffer: nil,
            sourceName: sourceName,
            canonicalUrl: propertyUrl,
            parcelId: nil,
            notes: "Google Maps loaded but no satellite imagery could be extracted"
        )
        print("🎉 [WebScrapingEngine] Google Maps scraping completed successfully without image")
        completeWithResult(.success(result))
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
        print("✅ [WebScrapingEngine] Page loaded successfully: \(webView.url?.absoluteString ?? "unknown")")
        
        // Only perform search if we haven't already started searching and haven't completed
        guard !isSearching && !hasCompleted else {
            print("⚠️ [WebScrapingEngine] Skipping search - already searching (\(isSearching)) or completed (\(hasCompleted))")
            return
        }
        
        // Check if this is Google Maps or property appraiser site
        let urlString = webView.url?.absoluteString ?? ""
        if urlString.contains("google.com/maps") {
            // Handle Google Maps aerial scraping
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🗺️ [WebScrapingEngine] Starting Google Maps aerial extraction after 2 second delay")
                self.performGoogleMapsExtraction()
            }
        } else {
            // Handle property appraiser scraping (legacy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("⏰ [WebScrapingEngine] Starting search after 1 second delay")
                self.performSearch()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebScrapingEngine] Navigation failed: \(error.localizedDescription)")
        completeWithResult(.failure(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebScrapingEngine] Provisional navigation failed: \(error.localizedDescription)")
        completeWithResult(.failure(error))
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🚀 [WebScrapingEngine] Started loading: \(webView.url?.absoluteString ?? "unknown")")
    }
}

// MARK: - WKUIDelegate

extension WebScrapingEngine: WKUIDelegate {
    // Handle any UI delegate methods if needed
}

// MARK: - Google Maps Aerial Scraper

class GoogleMapsAerialScraper: PropertyScraper {
    let name = "Google Maps Aerial Imagery"
    private let webEngine = WebScrapingEngine()
    
    func scrapeProperty(params: ScrapeParams) async throws -> ScrapeResult {
        return try await withCheckedThrowingContinuation { continuation in
            webEngine.scrapeGoogleMapsAerial(params: params) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Enhanced Hillsborough County Scraper (Commented Out)

/*
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
*/

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

