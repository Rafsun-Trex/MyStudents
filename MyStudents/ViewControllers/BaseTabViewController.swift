import UIKit

class BaseTabViewController: UIViewController {
    private let contentView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentView()
    }

    func applyScreenTitle(_ title: String) {
        self.title = title
        navigationItem.title = title
        contentView.configure(title: title)
    }

    private func setupContentView() {
        view.backgroundColor = .systemBackground
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
