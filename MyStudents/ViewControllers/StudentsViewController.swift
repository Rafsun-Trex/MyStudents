import UIKit

final class StudentsViewController: BaseTabViewController, StoryboardIdentifiable {
    var viewModel: StudentsViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyScreenTitle(viewModel?.title ?? AppTab.students.title)
    }
}
