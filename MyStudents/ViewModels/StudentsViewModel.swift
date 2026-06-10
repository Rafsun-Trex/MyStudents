import Foundation

final class StudentsViewModel: ScreenViewModel {
    let title = AppTab.students.title

    private let repository: StudentRepositoryProtocol

    init(repository: StudentRepositoryProtocol) {
        self.repository = repository
    }
}
