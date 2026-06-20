import CoreData
import Foundation

final class CoreDataBatchRepository: BatchRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func fetchBatches() throws -> [Batch] {
        let request = Batch.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Batch.name), ascending: true)
        ]
        return try persistenceService.viewContext.fetch(request)
    }

    func batch(withID id: UUID) throws -> Batch? {
        let request = Batch.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", "id", id as CVarArg)
        return try persistenceService.viewContext.fetch(request).first
    }

    @discardableResult
    func addBatch(_ formData: BatchFormData) throws -> Batch {
        let batch = Batch(context: persistenceService.viewContext)
        apply(formData, to: batch)
        try persistenceService.saveViewContext()
        return batch
    }

    func updateBatch(id: UUID, with formData: BatchFormData) throws {
        guard let batch = try batch(withID: id) else {
            throw BatchRepositoryError.batchNotFound
        }

        apply(formData, to: batch)
        try persistenceService.saveViewContext()
    }

    func deleteBatch(id: UUID) throws {
        guard let batch = try batch(withID: id) else {
            throw BatchRepositoryError.batchNotFound
        }

        persistenceService.viewContext.delete(batch)
        try persistenceService.saveViewContext()
    }

    func students(inBatch batchID: UUID) throws -> [Student] {
        guard let batch = try batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        return batch.students.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    func availableStudents(forBatch batchID: UUID) throws -> [Student] {
        guard let batch = try batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        let request = Student.fetchRequest()
        request.predicate = NSPredicate(format: "%K == NO", #keyPath(Student.isArchived))
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Student.fullName), ascending: true)
        ]

        let assigned = batch.students
        return try persistenceService.viewContext.fetch(request).filter { !assigned.contains($0) }
    }

    func assignStudents(_ studentIDs: [UUID], toBatch batchID: UUID) throws {
        guard let batch = try batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        let students = try fetchStudents(withIDs: studentIDs)
        guard !students.isEmpty else { return }

        batch.students = batch.students.union(students)
        try persistenceService.saveViewContext()
    }

    func removeStudent(_ studentID: UUID, fromBatch batchID: UUID) throws {
        guard let batch = try batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        batch.students = batch.students.filter { $0.id != studentID }
        try persistenceService.saveViewContext()
    }

    private func fetchStudents(withIDs ids: [UUID]) throws -> [Student] {
        guard !ids.isEmpty else { return [] }

        let request = Student.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", "id", ids)
        return try persistenceService.viewContext.fetch(request)
    }

    private func apply(_ formData: BatchFormData, to batch: Batch) {
        batch.name = formData.name.trimmingCharacters(in: .whitespacesAndNewlines)
        batch.subject = formData.subject.nilIfEmpty
        batch.schedule = formData.schedule.nilIfEmpty
        batch.fee = NSDecimalNumber(decimal: formData.fee)
    }
}

enum BatchRepositoryError: LocalizedError {
    case batchNotFound

    var errorDescription: String? {
        switch self {
        case .batchNotFound:
            "Batch not found."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
