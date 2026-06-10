import Foundation

final class BatchesViewModel: ScreenViewModel {
    let title = AppTab.batches.title

    private let repository: BatchRepositoryProtocol

    init(repository: BatchRepositoryProtocol) {
        self.repository = repository
    }
}
