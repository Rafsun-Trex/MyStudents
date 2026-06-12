import UIKit

final class AddStudentViewController: UIViewController {
    var onSave: (() -> Void)?

    private let viewModel: AddStudentViewModel
    private let formView = StudentFormView()

    init(viewModel: AddStudentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "AddStudentViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create AddStudentViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureForm()
    }

    private func configureNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func configureForm() {
        view.backgroundColor = .systemGroupedBackground
        formView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formView)

        NSLayoutConstraint.activate([
            formView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            formView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            formView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        formView.configure(with: .empty)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        do {
            try viewModel.save(formData: formView.formData)
            onSave?()
            dismiss(animated: true)
        } catch {
            showError(error)
        }
    }
}
