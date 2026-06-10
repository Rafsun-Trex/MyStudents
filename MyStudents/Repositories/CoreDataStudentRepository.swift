import Foundation

final class CoreDataStudentRepository: StudentRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchStudents() throws -> [Student] {
        []
    }

    func student(withID id: UUID) throws -> Student? {
        nil
    }
}
