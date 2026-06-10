import UIKit

final class DashboardViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: DashboardViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.dashboard.title)
    }
}
