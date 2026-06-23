import CoreData
import Foundation

protocol DashboardRepositoryProtocol {
    /// The Core Data context used for fetches, exposed so the dashboard
    /// can refresh when any other module saves a change.
    var managedObjectContext: NSManagedObjectContext { get }

    func fetchSummary() throws -> DashboardSummary
}
