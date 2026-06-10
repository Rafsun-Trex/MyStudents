import UIKit

final class FinanceViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: FinanceViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.finance.title)
    }
}
