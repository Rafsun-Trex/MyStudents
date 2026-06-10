import UIKit

final class AttendanceViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: AttendanceViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.attendance.title)
    }
}
