import UIKit

final class BatchesViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: BatchesViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.batches.title)
    }
}
