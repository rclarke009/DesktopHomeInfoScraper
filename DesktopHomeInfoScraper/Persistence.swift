//
//  Persistence.swift
//  DesktopHomeInfoScraper
//
//  Created by Rebecca Clarke on 9/26/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample jobs for preview
        let sampleJobs = [
            ("E2025-05091", "Smith", "408 2nd Ave NW", "Largo", "FL", "33770"),
            ("E2025-05092", "Johnson", "1121 Palm Dr", "Clearwater", "FL", "33755"),
            ("E2025-05093", "Williams", "2500 Main St", "Tampa", "FL", "33602")
        ]
        
        for (jobId, client, address, city, state, zip) in sampleJobs {
            let job = Job(context: viewContext)
            job.jobId = jobId
            job.clientName = client
            job.addressLine1 = address
            job.city = city
            job.state = state
            job.zip = zip
            job.status = "queued"
            job.createdAt = Date()
            job.updatedAt = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DesktopHomeInfoScraper")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
