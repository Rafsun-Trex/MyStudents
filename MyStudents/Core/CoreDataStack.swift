import CoreData
import os

protocol CoreDataStackProviding: AnyObject {
    var viewContext: NSManagedObjectContext { get }

    func newBackgroundContext() -> NSManagedObjectContext
    func saveContext() throws
}

final class CoreDataStack: CoreDataStackProviding {
    let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    init(
        modelName: String = "MyStudents",
        cloudSyncConfiguration: CloudSyncConfiguration = .disabled,
        inMemory: Bool = false
    ) {
        self.persistentContainer = Self.makePersistentContainer(
            modelName: modelName,
            cloudSyncConfiguration: cloudSyncConfiguration,
            inMemory: inMemory
        )

        loadPersistentStores(modelName: modelName, cloudSyncConfiguration: cloudSyncConfiguration)
        configureContexts()
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }

    private static func makePersistentContainer(
        modelName: String,
        cloudSyncConfiguration: CloudSyncConfiguration,
        inMemory: Bool
    ) -> NSPersistentContainer {
        let container: NSPersistentContainer

        if cloudSyncConfiguration.isEnabled {
            container = NSPersistentCloudKitContainer(name: modelName)
        } else {
            container = NSPersistentContainer(name: modelName)
        }

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Opt in to lightweight migration so additive schema changes (new optional
        // attributes, new entities, etc.) don't require manual mapping models.
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        if inMemory {
            description.type = NSInMemoryStoreType
        }

        if cloudSyncConfiguration.isEnabled,
           let identifier = cloudSyncConfiguration.containerIdentifier {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: identifier
            )
        }

        container.persistentStoreDescriptions = [description]
        return container
    }

    private func loadPersistentStores(modelName: String, cloudSyncConfiguration: CloudSyncConfiguration) {
        if let storeURL = persistentContainer.persistentStoreDescriptions.first?.url {
            AppLogger.coreData.info("Loading persistent store at \(storeURL.path, privacy: .public)")
        }

        persistentContainer.loadPersistentStores { [weak persistentContainer] description, error in
            guard let error else { return }

            AppLogger.coreData.error(
                "Failed to load persistent store \(description.url?.path ?? "<unknown>", privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            #if DEBUG
            guard
                let persistentContainer,
                let storeURL = description.url,
                Self.destroyStoreFiles(at: storeURL)
            else {
                preconditionFailure(
                    "Unable to load \(modelName) persistent store and recovery failed. Cloud sync enabled: \(cloudSyncConfiguration.isEnabled). Error: \(error)"
                )
            }

            AppLogger.coreData.warning(
                "[DEBUG] Recreated empty persistent store after migration failure. Previous data has been discarded."
            )

            persistentContainer.loadPersistentStores { _, retryError in
                if let retryError {
                    preconditionFailure(
                        "Unable to load \(modelName) after destroy+recreate. Error: \(retryError)"
                    )
                }
            }
            #else
            preconditionFailure(
                "Unable to load \(modelName) persistent store. Cloud sync enabled: \(cloudSyncConfiguration.isEnabled). Error: \(error)"
            )
            #endif
        }
    }

    private func configureContexts() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Removes the SQLite store and its sidecar files at `storeURL`. Used as a
    /// last-resort recovery path in DEBUG when the model has changed in a way
    /// that lightweight migration cannot handle. Returns false if any file
    /// that exists fails to delete.
    private static func destroyStoreFiles(at storeURL: URL) -> Bool {
        let fileManager = FileManager.default
        let candidates = [
            storeURL,
            storeURL.appendingPathExtension("wal"),
            storeURL.appendingPathExtension("shm"),
            storeURL.deletingLastPathComponent().appendingPathComponent(".\(storeURL.lastPathComponent)_SUPPORT", isDirectory: true)
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                AppLogger.coreData.error(
                    "Failed to remove \(url.lastPathComponent, privacy: .public) during recovery: \(error.localizedDescription, privacy: .public)"
                )
                return false
            }
        }
        return true
    }
}
