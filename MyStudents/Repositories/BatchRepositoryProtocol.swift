import Foundation

protocol BatchRepositoryProtocol {
    func fetchBatches() throws -> [Batch]
    func batch(withID id: UUID) throws -> Batch?
    @discardableResult
    func addBatch(_ formData: BatchFormData) throws -> Batch
    func updateBatch(id: UUID, with formData: BatchFormData) throws
    func deleteBatch(id: UUID) throws

    func students(inBatch batchID: UUID) throws -> [Student]
    func availableStudents(forBatch batchID: UUID) throws -> [Student]
    func assignStudents(_ studentIDs: [UUID], toBatch batchID: UUID) throws
    func removeStudent(_ studentID: UUID, fromBatch batchID: UUID) throws
}
