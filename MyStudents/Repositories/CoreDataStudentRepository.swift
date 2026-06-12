import CoreData
import Foundation

final class CoreDataStudentRepository: StudentRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchStudents(includeArchived: Bool = false) throws -> [Student] {
        let request = Student.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Student.fullName), ascending: true)
        ]

        if !includeArchived {
            request.predicate = NSPredicate(format: "%K == NO", #keyPath(Student.isArchived))
        }

        return try persistenceService.viewContext.fetch(request)
    }

    func student(withID id: UUID) throws -> Student? {
        let request = Student.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", "id", id as CVarArg)
        return try persistenceService.viewContext.fetch(request).first
    }

    @discardableResult
    func addStudent(_ formData: StudentFormData) throws -> Student {
        let student = Student(context: persistenceService.viewContext)
        apply(formData, to: student)
        try persistenceService.saveViewContext()
        return student
    }

    func updateStudent(id: UUID, with formData: StudentFormData) throws {
        guard let student = try student(withID: id) else {
            throw StudentRepositoryError.studentNotFound
        }

        apply(formData, to: student)
        try persistenceService.saveViewContext()
    }

    func deleteStudent(id: UUID) throws {
        guard let student = try student(withID: id) else {
            throw StudentRepositoryError.studentNotFound
        }

        persistenceService.viewContext.delete(student)
        try persistenceService.saveViewContext()
    }

    func archiveStudent(id: UUID) throws {
        guard let student = try student(withID: id) else {
            throw StudentRepositoryError.studentNotFound
        }

        student.isArchived = true
        try persistenceService.saveViewContext()
    }

    private func apply(_ formData: StudentFormData, to student: Student) {
        student.fullName = formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        student.guardianName = formData.guardianName.nilIfEmpty
        student.phoneNumber = formData.phoneNumber.nilIfEmpty
        student.school = formData.school.nilIfEmpty
        student.className = formData.className.nilIfEmpty
        student.admissionDate = formData.admissionDate
        student.monthlyFee = NSDecimalNumber(decimal: formData.monthlyFee)
        student.notes = formData.notes.nilIfEmpty
    }
}

enum StudentRepositoryError: LocalizedError {
    case studentNotFound

    var errorDescription: String? {
        switch self {
        case .studentNotFound:
            "Student not found."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
