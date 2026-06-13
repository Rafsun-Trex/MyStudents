import UIKit

final class StudentDetailViewController: UIViewController {
    var onChange: (() -> Void)?

    private let viewModel: StudentDetailViewModel
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(viewModel: StudentDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "StudentDetailViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create StudentDetailViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureLayout()
        render(viewModel.detail)
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editTapped)),
            UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: self,
                action: #selector(moreTapped)
            )
        ]
    }

    private func configureLayout() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func render(_ detail: StudentDetailData) {
        title = detail.fullName
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let nameLabel = UILabel()
        nameLabel.font = .preferredFont(forTextStyle: .largeTitle)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        nameLabel.text = detail.fullName
        stackView.addArrangedSubview(nameLabel)

        [
            ("Guardian", detail.guardianName),
            ("Phone", detail.phoneNumber),
            ("School", detail.school),
            ("Class", detail.className),
            ("Admission Date", detail.admissionDate),
            ("Monthly Fee", detail.monthlyFee),
            ("Notes", detail.notes)
        ].forEach { title, value in
            stackView.addArrangedSubview(makeDetailRow(title: title, value: value))
        }
    }

    private func makeDetailRow(title: String, value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 8

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title.uppercased()

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.text = value

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),

            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    private func reloadDetail() {
        do {
            render(try viewModel.reload())
            onChange?()
        } catch {
            showError(error)
        }
    }

    @objc private func editTapped() {
        do {
            let editViewController = EditStudentViewController(viewModel: try viewModel.makeEditStudentViewModel())
            editViewController.onSave = { [weak self] in
                self?.reloadDetail()
            }
            navigationController?.pushViewController(editViewController, animated: true)
        } catch {
            showError(error)
        }
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Archive Student", style: .default) { [weak self] _ in
            self?.archiveStudent()
        })
        alert.addAction(UIAlertAction(title: "Delete Student", style: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func archiveStudent() {
        do {
            try viewModel.archiveStudent()
            onChange?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error)
        }
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete Student?",
            message: "This permanently removes the student record.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteStudent()
        })
        present(alert, animated: true)
    }

    private func deleteStudent() {
        do {
            try viewModel.deleteStudent()
            onChange?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error)
        }
    }
}
