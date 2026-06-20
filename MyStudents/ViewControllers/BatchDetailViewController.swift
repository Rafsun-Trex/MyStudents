import UIKit

final class BatchDetailViewController: UIViewController {
    var onChange: (() -> Void)?

    private enum Section: Int, CaseIterable {
        case details
        case students
    }

    private struct DetailRow {
        let title: String
        let value: String
    }

    private let viewModel: BatchDetailViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var detailRows: [DetailRow] = []
    private var students: [BatchStudentItem] = []

    init(viewModel: BatchDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "BatchDetailViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create BatchDetailViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureTableView()
        reloadAll()
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

    private func configureTableView() {
        view.backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BatchDetailCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BatchStudentCell")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func reloadAll() {
        do {
            let detail = try viewModel.reload()
            title = detail.name
            detailRows = [
                DetailRow(title: "Subject", value: detail.subject),
                DetailRow(title: "Schedule", value: detail.schedule),
                DetailRow(title: "Fee", value: detail.fee),
                DetailRow(title: "Students", value: "\(detail.studentCount)")
            ]
            students = try viewModel.loadStudents()
            tableView.reloadData()
            onChange?()
        } catch {
            showError(error)
        }
    }

    private func reloadStudentsOnly() {
        do {
            let detail = try viewModel.reload()
            detailRows[3] = DetailRow(title: "Students", value: "\(detail.studentCount)")
            students = try viewModel.loadStudents()
            tableView.reloadData()
            onChange?()
        } catch {
            showError(error)
        }
    }

    @objc private func editTapped() {
        do {
            let editViewController = CreateBatchViewController(viewModel: try viewModel.makeEditBatchViewModel())
            editViewController.showsCancelButton = false
            editViewController.onSave = { [weak self] in
                self?.reloadAll()
            }
            navigationController?.pushViewController(editViewController, animated: true)
        } catch {
            showError(error)
        }
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Assign Students", style: .default) { [weak self] _ in
            self?.assignStudentsTapped()
        })
        alert.addAction(UIAlertAction(title: "Delete Batch", style: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(alert, animated: true)
    }

    private func assignStudentsTapped() {
        let assignViewController = AssignStudentsViewController(viewModel: viewModel.makeAssignStudentsViewModel())
        assignViewController.onComplete = { [weak self] in
            self?.reloadStudentsOnly()
        }
        let navigationController = UINavigationController(rootViewController: assignViewController)
        present(navigationController, animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete Batch?",
            message: "This permanently removes the batch. Students will not be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteBatch()
        })
        present(alert, animated: true)
    }

    private func deleteBatch() {
        do {
            try viewModel.deleteBatch()
            onChange?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error)
        }
    }

    private func removeStudent(at indexPath: IndexPath) {
        let student = students[indexPath.row]
        do {
            students = try viewModel.removeStudent(id: student.id)
            let detail = try viewModel.reload()
            detailRows[3] = DetailRow(title: "Students", value: "\(detail.studentCount)")
            tableView.reloadData()
            onChange?()
        } catch {
            showError(error)
        }
    }
}

extension BatchDetailViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .details:
            return detailRows.count
        case .students:
            return max(students.count, 1)
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .details:
            return "Details"
        case .students:
            return "Students"
        case .none:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .details:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BatchDetailCell", for: indexPath)
            let row = detailRows[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = row.title
            content.secondaryText = row.value
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell

        case .students:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BatchStudentCell", for: indexPath)
            var content = cell.defaultContentConfiguration()

            if students.isEmpty {
                content.text = "No students assigned"
                content.textProperties.color = .secondaryLabel
                cell.selectionStyle = .none
            } else {
                let student = students[indexPath.row]
                content.text = student.fullName
                content.secondaryText = student.subtitle
                cell.selectionStyle = .default
            }

            cell.contentConfiguration = content
            return cell

        case .none:
            return UITableViewCell()
        }
    }
}

extension BatchDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .students, !students.isEmpty else {
            return nil
        }

        let removeAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completion in
            self?.removeStudent(at: indexPath)
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [removeAction])
    }
}
