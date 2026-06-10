import CoreData

protocol PersistenceServiceProtocol: AnyObject {
    var viewContext: NSManagedObjectContext { get }

    func newBackgroundContext() -> NSManagedObjectContext
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
    func saveViewContext() throws
}

final class CoreDataPersistenceService: PersistenceServiceProtocol {
    private let coreDataStack: CoreDataStackProviding

    var viewContext: NSManagedObjectContext {
        coreDataStack.viewContext
    }

    init(coreDataStack: CoreDataStackProviding) {
        self.coreDataStack = coreDataStack
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        coreDataStack.newBackgroundContext()
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            block(context)
        }
    }

    func saveViewContext() throws {
        try coreDataStack.saveContext()
    }
}
