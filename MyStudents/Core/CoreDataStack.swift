import CoreData

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
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                preconditionFailure(
                    "Unable to load \(modelName) persistent store. Cloud sync enabled: \(cloudSyncConfiguration.isEnabled). Error: \(error)"
                )
            }
        }
    }

    private func configureContexts() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
