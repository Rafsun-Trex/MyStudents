import UIKit

final class EditStudentViewController: UIViewController {
    var onSave: (() -> Void)?

    private let viewModel: EditStudentViewModel
    private let formView = StudentFormView()

    init(viewModel: EditStudentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "EditStudentViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create EditStudentViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureForm()
    }

    private func configureNavigation() {
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

    @objc private func saveTapped() {
        do {
            try viewModel.save(formData: formView.formData)
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error)
        }
    }
}
