import Foundation

protocol StudentRepositoryProtocol {
    func fetchStudents() throws -> [Student]
    func student(withID id: UUID) throws -> Student?
}
