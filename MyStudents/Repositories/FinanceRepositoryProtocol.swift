import Foundation

protocol FinanceRepositoryProtocol {
    func fetchPayments() throws -> [Payment]
    func fetchPayments(forStudentID studentID: UUID) throws -> [Payment]
}
