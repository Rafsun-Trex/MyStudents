import Foundation

protocol DashboardRepositoryProtocol {
    func fetchSummary() throws -> DashboardSummary
}
