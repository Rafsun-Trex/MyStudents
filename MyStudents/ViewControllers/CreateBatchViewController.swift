import UIKit

final class CreateBatchViewController: UIViewController {
    var onSave: (() -> Void)?

    /// When `true` a Cancel button is shown and a successful save dismisses the
    /// presented controller. When `false` the screen behaves as a pushed editor
    /// and pops on save. Set before presenting/pushing.
    var showsCancelButton = false

    private let viewModel: BatchFormViewModel
    private let formView = BatchFormView()

    init(viewModel: BatchFormViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "CreateBatchViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create CreateBatchViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureForm()
        hideKeyboardWhenTappedAround()
    }

    private func configureNavigation() {
        if showsCancelButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancelTapped)
            )
        }
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

        formView.configure(with: viewModel.initialFormData)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        do {
            try viewModel.save(formData: formView.formData)
            onSave?()
            if showsCancelButton {
                dismiss(animated: true)
            } else {
                navigationController?.popViewController(animated: true)
            }
        } catch {
            showError(error)
        }
    }
}
