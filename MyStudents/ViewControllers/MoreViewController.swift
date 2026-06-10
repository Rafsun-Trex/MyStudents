import UIKit

final class MoreViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: MoreViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.more.title)
    }
}
