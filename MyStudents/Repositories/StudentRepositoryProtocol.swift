import Foundation

protocol StudentRepositoryProtocol {
    func fetchStudents(includeArchived: Bool) throws -> [Student]
    func student(withID id: UUID) throws -> Student?
    @discardableResult
    func addStudent(_ formData: StudentFormData) throws -> Student
    func updateStudent(id: UUID, with formData: StudentFormData) throws
    func deleteStudent(id: UUID) throws
    func archiveStudent(id: UUID) throws
}
