import Foundation

final class CoreDataAttendanceRepository: AttendanceRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchAttendanceRecords() throws -> [AttendanceRecord] {
        []
    }

    func fetchAttendanceRecords(forStudentID studentID: UUID) throws -> [AttendanceRecord] {
        []
    }
}
