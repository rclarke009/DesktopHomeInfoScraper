//
//  requirements.swift
//  WindowTest
//
//  Created by Rebecca Clarke on 9/26/25.
//


That sounds great—and simpler for the iPad team. Here’s a **Cursor-ready MD requirements doc** updated for a **two-app architecture**: a desktop “Scraper & Dispatcher” + the field iPad app.

---

# Window Test Suite — v1 Requirements (Desktop + iPad)

*Last updated: 2025-09-26 • Audience: Engineering/Design • Handoff: Cursor-ready*

## A) System Overview

Two cooperating apps:

1. **Desktop Scraper & Dispatcher (macOS/Windows)**

   * Ingests an address list (CSV/XLSX).
   * Scrapes building-department/parcel/permit portals using a bundled Playwright engine.
   * Lets an operator review/approve the best **overhead/floorplan image** per property.
   * Exports **Job Intake Packages** and delivers them to the iPad app.

2. **Window Test (iPad)**

   * Imports Job Packages, lets techs pin window locations, capture measurements (ARKit), conditions, photos, and pass/fail & leaks.
   * Exports a **Field Results Package** (JSON/CSV + photos + DOCX/PDF).

The two packages are symmetrical and can be round-tripped if needed.

---

## B) Inter-App Data Flow

1. **Address → Desktop**

   * Admin drops a CSV of upcoming jobs.
2. **Desktop Scrape**

   * Scraper finds/produces one overhead/floorplan image per address (+ source metadata).
3. **Desktop Export → “Job Intake Package”**

   * One zip per address or one multi-job zip.
4. **Delivery to iPad**

   * Options (choose any two for v1):

     * **Shared folder** (iCloud Drive/OneDrive/Dropbox) the iPad Files app can access.
     * **Pre-signed S3 links** (download inside iPad app).
     * **AirDrop** from desktop to iPad (opens in app).
5. **Field Work → iPad Export**

   * Tech completes tests, exports **Field Results Package** back to the same shared folder (or AirDrop/email on Wi-Fi).

---

## C) File Formats

### C1) Job Intake Package (from Desktop → iPad)

**Zip root**

```
/JOB_INTake_{City}_{YYYYMMDD}/
  jobs.json
  overhead/
    {JobId}_overhead.jpg
  source_docs/            // optional raw PDFs/screens
    {JobId}_source.pdf
```

**`jobs.json`**

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
      "notes": "",
      "overhead": {
        "imageFile": "overhead/E2025-05091_overhead.jpg",
        "source": {
          "name": "Pinellas County Property Appraiser",
          "url": "https://…/parcel/…",
          "fetchedAt": "2025-09-26T14:00:10Z"
        },
        "scalePixelsPerFoot": null
      }
    }
  ]
}
```

### C2) Field Results Package (from iPad → Desktop/Engineer)

(as previously specified; unchanged except now includes a backlink to the intake metadata)

```
/{JobID}_{City}_{YYYYMMDD}/
  job.json                 // includes intake.source and iPad-captured data
  windows.csv
  overhead_with_dots.png
  photos/
    W01_Exterior_1.jpg
    W01_Interior_1.jpg
    W01_Leak_1.jpg
  report/
    WindowTests.docx
    WindowTests.pdf (optional)
```

**`job.json` (delta)**

```json
{
  "intake": {
    "sourceName": "Pinellas County Property Appraiser",
    "sourceUrl": "https://…",
    "fetchedAt": "2025-09-26T14:00:10Z"
  },
  "field": {
    "inspector": "Jane Tech",
    "date": "2025-09-26",
    "overheadFile": "overhead_with_dots.png",
    "windows": [ /* same window schema as prior spec */ ]
  }
}
```

---

## D) Desktop Scraper & Dispatcher (Detailed)

### D1) Features

* **Import addresses**: CSV/XLSX columns: `JobID (optional)`, `Client`, `Line1`, `City`, `State`, `ZIP`, `Notes`.
* **Batch scrape** with **Playwright** headless browser:

  * Modular **jurisdiction adapters** (Pinellas, Hillsborough, Pasco, Orange, Miami-Dade, Broward).
  * Save an **image** (JPG/PNG) and citation URL for each job.
* **Operator review UI**:

  * Queue view with thumbnails, status (Queued/Running/Succeeded/Failed).
  * Approve/browse multiple candidates; crop & rotate; set a **reference scale** (drag over a known dimension).
  * Mark as **No Data** with reason (Captcha/Paywall/No Match/Rate-Limit).
* **Export Job Intake Package**:

  * One zip per job or batch zip.
  * Optional include of **source_docs** (PDF/pages screenshots).
* **Delivery**:

  * Write to a configured **Sync Folder** (iCloud/Dropbox/OneDrive) *and/or* generate **pre-signed URLs** list (`download_manifest.json`) for the iPad app.

### D2) Tech Stack (Desktop)

* **Electron** (cross-platform) or **Native macOS** (SwiftUI + WKWebView for admin UI) + background **Node/Playwright** process.
* **Playwright** for scraping.
* **SQLite** for run logs & retry state.
* **Queue**: BullMQ (if Node) or simple persisted queue.
* **Rate limiting** per domain; polite delays; user-agent string configurable.
* **No** captcha solving or paywall bypassing.

### D3) Adapter Contract

```ts
export interface ScrapeParams { addressLine1: string; city: string; state: string; zip?: string; }
export interface ScrapeResult {
  imageBuffer: Buffer;
  sourceName: string;
  canonicalUrl: string;
  parcelId?: string;
  notes?: string;
}
```

### D4) Acceptance Criteria (Desktop)

* From a 100-address FL sample, **≥80** jobs produce a usable overhead image within **≤120s** each (p50 ≤60s).
* Operator can approve/crop each image; exported Job Intake Package opens on iPad with correct previews.
* “No Data” cases carry reason codes into `jobs.json`.

---

## E) iPad App (Field) — Key Points (unchanged, adjusted for import)

### E1) Import Jobs

* **Open Package**: from Files app, shared folder, download link, or AirDrop → app imports `jobs.json` and images.
* Jobs List shows **“Ready”** status for each imported job.

### E2) Overhead Canvas

* Loads `overhead/{JobId}_overhead.jpg` (or PDF page) from intake.
* Source badge (name + info icon) retained.
* Tap to add/move/delete **Window Dots**; export `overhead_with_dots.png`.

### E3) Measurements / Types / Conditions / Results / Photos

* Same as previously specified (ARKit + manual; required photo sets; leak points).

### E4) Export

* **Field Results Package** (zip) per job to the same shared folder (or AirDrop/mail).
* DOCX section page 1 shows `overhead_with_dots.png` + optional source credit.

### E5) Acceptance Criteria (iPad)

* Add **8 windows** (incl. 1 Fail + 2 leak points, 1 Not Accessible) in **≤12 min**, no crashes.
* Completeness rules enforced; cannot complete/export with missing required photos.
* Import a multi-job intake zip; show N jobs ready; open one and proceed.

---

## F) Security & Privacy

* Desktop stores only: address list, run logs, images, and `jobs.json`; all local.
* Respect sites’ **ToS/robots**; adapter has throttle & domain notes.
* Packages contain only necessary PII; engineers handle secure storage once exported.
* No cloud services required unless team enables S3 pre-signed delivery.

---

## G) Delivery Options (pick two for v1)

1. **Shared Folder** (recommended): configure same iCloud/Dropbox account on desktop and iPad; packages sync automatically.
2. **AirDrop**: quick ad-hoc push to the tech’s iPad (opens in app).
3. **S3 Pre-signed**: desktop generates `download_manifest.json`; iPad app downloads and imports when online.

---

## H) Open Questions

1. Which **two delivery methods** do you want in v1 (I recommend Shared Folder + AirDrop)?
2. Do you want the desktop app to **auto-assign Job IDs**, or will the CSV provide them?
3. Any jurisdictions beyond the FL top six to prioritize for adapters?
4. Should the desktop operator be able to set a **pixels/ft scale** during review (handy for plan sheets)?

---

## I) Quick CSV Spec (Desktop Import)

Columns (case-insensitive):
`JobID?, Client, AddressLine1, City, State, Zip, Notes?`

Example:

```
E2025-05091, Smith, 408 2nd Ave NW, Largo, FL, 33770, Rush
E2025-05092, Johnson, 1121 Palm Dr, Clearwater, FL, 33755,
```

---

If you’d like, I can now generate:

* The **Job Intake Package skeleton** (JSON schemas + sample zips).
* A starter **Electron + Playwright** desktop project (one working adapter).
* The **iPad import screen scaffold** wired to Files/AirDrop and package parsing.

