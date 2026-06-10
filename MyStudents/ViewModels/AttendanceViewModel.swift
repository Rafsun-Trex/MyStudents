import Foundation

final class AttendanceViewModel: ScreenViewModel {
    let title = AppTab.attendance.title

    private let repository: AttendanceRepositoryProtocol

    init(repository: AttendanceRepositoryProtocol) {
        self.repository = repository
    }
}
