import Foundation

final class CoreDataDashboardRepository: DashboardRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchSummary() throws -> DashboardSummary {
        .empty
    }
}
