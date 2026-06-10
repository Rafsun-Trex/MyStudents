import Foundation

protocol BatchRepositoryProtocol {
    func fetchBatches() throws -> [Batch]
    func batch(withID id: UUID) throws -> Batch?
}
