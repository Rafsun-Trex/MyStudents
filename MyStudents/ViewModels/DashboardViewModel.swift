import Foundation

final class DashboardViewModel: ScreenViewModel {
    let title = AppTab.dashboard.title

    private let repository: DashboardRepositoryProtocol

    init(repository: DashboardRepositoryProtocol) {
        self.repository = repository
    }
}
