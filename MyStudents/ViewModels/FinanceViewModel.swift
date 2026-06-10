import Foundation

final class FinanceViewModel: ScreenViewModel {
    let title = AppTab.finance.title

    private let repository: FinanceRepositoryProtocol

    init(repository: FinanceRepositoryProtocol) {
        self.repository = repository
    }
}
