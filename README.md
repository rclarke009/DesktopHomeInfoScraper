# Desktop Home Info Scraper

A macOS application for scraping property information from Florida county property appraiser websites, specifically designed to work with the Hillsborough County Property Appraiser (https://www.hcpafl.org) and other Florida property databases.

## Features

### 🏠 Property Data Scraping
- **Multi-County Support**: Hillsborough, Pinellas, Pasco, and other Florida counties
- **Web Scraping Engine**: Uses WKWebView for reliable property data extraction
- **Fallback System**: Multiple scrapers with fallback options for maximum success rate
- **Rate Limiting**: Respectful scraping with built-in delays and error handling

### 📊 Job Management
- **CSV Import**: Import job lists with addresses and client information
- **Queue Management**: Visual job queue with status tracking (Queued, Running, Completed, Failed)
- **Batch Processing**: Process multiple jobs automatically
- **Progress Tracking**: Real-time progress updates during scraping operations

### 🖼️ Image Processing
- **Property Images**: Automatic extraction of overhead/aerial property images
- **Image Editor**: Built-in editor for cropping, rotating, and scaling images
- **Scale Reference**: Set pixel-to-foot scale for accurate measurements
- **Format Support**: JPEG/PNG image handling with optimization

### 📦 Export & Delivery
- **Job Intake Packages**: Export structured data for iPad field app
- **Multiple Formats**: JSON metadata with image files
- **Delivery Options**: Shared folder, AirDrop, and S3 pre-signed URLs
- **Source Documentation**: Include original source URLs and metadata

## Architecture

### Core Data Model
- **Job Entity**: Stores job information, addresses, and scraping results
- **ScrapingSession Entity**: Groups related jobs for batch processing
- **Relationships**: Proper Core Data relationships for data integrity

### Scraping System
- **PropertyScraper Protocol**: Modular scraper architecture
- **WebScrapingEngine**: WKWebView-based web interaction
- **Enhanced Scrapers**: Sophisticated JavaScript-based data extraction
- **Fallback Scrapers**: Reliable fallback when web scraping fails

### UI Components
- **ContentView**: Main interface with job queue and controls
- **CSVImportView**: File import with validation and error handling
- **JobDetailView**: Individual job review and approval interface
- **ImageEditorView**: Image editing and scale setting tools
- **ExportOptionsView**: Export format and delivery method selection

## Usage

### 1. Import Jobs
1. Click "Import CSV File" in the sidebar
2. Select a CSV file with the required columns:
   - `JobID` (optional)
   - `Client`
   - `AddressLine1`
   - `City`
   - `State`
   - `Zip` (optional)
   - `Notes` (optional)

### 2. Start Scraping
1. Click "Start Scraping" to begin processing queued jobs
2. Monitor progress in the job list
3. Jobs will automatically move through: Queued → Running → Completed/Failed

### 3. Review & Approve
1. Click on any completed job to open the detail view
2. Review the scraped property image
3. Use the image editor to crop, rotate, or set scale
4. Approve jobs that have good quality images

### 4. Export Packages
1. Click "Export Job Package" for approved jobs
2. Choose export format (Job Intake Package or Field Results Package)
3. Select delivery method (Shared Folder, AirDrop, or S3)
4. Export creates a structured package for the iPad field app

## Sample CSV Format

```csv
JobID,Client,AddressLine1,City,State,Zip,Notes
E2025-05091,Smith,408 2nd Ave NW,Largo,FL,33770,Rush job
E2025-05092,Johnson,1121 Palm Dr,Clearwater,FL,33755,Standard inspection
E2025-05093,Williams,2500 Main St,Tampa,FL,33602,High priority
```

## Export Package Structure

### Job Intake Package
```
/JOB_INTAKE_{City}_{YYYYMMDD}/
  jobs.json                    # Job metadata
  overhead/                    # Property images
    {JobId}_overhead.jpg
  source_docs/                 # Optional source documents
    {JobId}_source.pdf
```

### jobs.json Format
```json
{
  "version": "1.0",
  "createdAt": "2025-09-26T14:12:00Z",
  "preparedBy": "DesktopScraper 1.0.0",
  "jobs": [
    {
      "jobId": "E2025-05091",
      "clientName": "Smith",
      "address": {
        "line1": "408 2nd Ave NW",
        "city": "Largo",
        "state": "FL",
        "zip": "33770"
      },
      "overhead": {
        "imageFile": "overhead/E2025-05091_overhead.jpg",
        "source": {
          "name": "Hillsborough County Property Appraiser",
          "url": "https://www.hcpafl.org/...",
          "fetchedAt": "2025-09-26T14:00:10Z"
        },
        "scalePixelsPerFoot": 12.5
      }
    }
  ]
}
```

## Technical Details

### Dependencies
- **SwiftUI**: Modern macOS UI framework
- **Core Data**: Local data persistence
- **WKWebView**: Web scraping engine
- **UniformTypeIdentifiers**: File type handling

### Scraping Strategy
1. **Primary**: Enhanced web scraping with JavaScript execution
2. **Fallback**: Placeholder image generation with property data
3. **Error Handling**: Comprehensive error reporting and retry logic
4. **Rate Limiting**: Respectful delays between requests

### Performance
- **Batch Processing**: Efficient queue-based job processing
- **Memory Management**: Proper cleanup of web views and images
- **Background Processing**: Non-blocking UI during scraping operations

## Development Status

### ✅ Completed
- Core Data model design and implementation
- Main UI with job queue and import functionality
- Web scraping engine with WKWebView
- Hillsborough County Property Appraiser adapter
- Job intake package export functionality
- Image review and editing capabilities

### 🚧 In Progress
- Enhanced web scraping with Playwright integration
- Delivery options (shared folder, AirDrop, S3)
- Rate limiting and advanced error handling

### 📋 Planned
- Additional county scrapers (Orange, Miami-Dade, Broward)
- Advanced image processing (OCR, property boundary detection)
- Cloud sync integration
- Batch export optimizations

## Requirements

- **macOS**: 12.0 or later
- **Xcode**: 14.0 or later
- **Swift**: 5.7 or later

## Installation

1. Clone the repository
2. Open `DesktopHomeInfoScraper.xcodeproj` in Xcode
3. Build and run the project
4. Import the provided `sample_jobs.csv` to test the functionality

## Contributing

This app is designed to work specifically with Florida property appraiser websites. When adding new scrapers:

1. Implement the `PropertyScraper` protocol
2. Add proper error handling and rate limiting
3. Test with various address formats
4. Update the scraper list in `ScrapingManager`

## License

This project is part of the Window Test Suite for property inspection workflows.
