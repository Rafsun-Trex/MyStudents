import Foundation

final class CoreDataBatchRepository: BatchRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchBatches() throws -> [Batch] {
        []
    }

    func batch(withID id: UUID) throws -> Batch? {
        nil
    }
}
