import Foundation

final class CoreDataFinanceRepository: FinanceRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchPayments() throws -> [Payment] {
        []
    }

    func fetchPayments(forStudentID studentID: UUID) throws -> [Payment] {
        []
    }
}
