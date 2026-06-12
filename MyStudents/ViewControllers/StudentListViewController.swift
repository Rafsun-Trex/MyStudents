import UIKit

final class StudentListViewController: UIViewController {
    private let viewModel: StudentsViewModel
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: StudentListItem] = [:]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private let refreshControl = UIRefreshControl()

    init(viewModel: StudentsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "StudentListViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create StudentListViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureTableView()
        configureEmptyState()
        configureSearch()
        configureDataSource()
        loadStudents()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .automatic
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addStudentTapped)
        )
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StudentCell")
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshStudents), for: .valueChanged)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true

        emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyTitleLabel.text = "No Students"
        emptyTitleLabel.font = .preferredFont(forTextStyle: .title2)
        emptyTitleLabel.adjustsFontForContentSizeCategory = true
        emptyTitleLabel.textAlignment = .center

        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.text = "Tap Add to create your first student."
        emptyMessageLabel.font = .preferredFont(forTextStyle: .body)
        emptyMessageLabel.adjustsFontForContentSizeCategory = true
        emptyMessageLabel.textColor = .secondaryLabel
        emptyMessageLabel.numberOfLines = 0
        emptyMessageLabel.textAlignment = .center

        emptyStateView.addSubview(emptyTitleLabel)
        emptyStateView.addSubview(emptyMessageLabel)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyTitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyTitleLabel.topAnchor.constraint(equalTo: emptyStateView.topAnchor),

            emptyMessageLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyMessageLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyMessageLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 8),
            emptyMessageLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }

    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search students"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, UUID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, studentID in
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudentCell", for: indexPath)
            guard let item = self?.itemsByID[studentID] else { return cell }
            var content = cell.defaultContentConfiguration()
            content.text = item.fullName
            content.secondaryText = "\(item.subtitle)\n\(item.detail)"
            content.secondaryTextProperties.numberOfLines = 2
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    private func loadStudents() {
        do {
            applySnapshot(try viewModel.loadStudents())
        } catch {
            showStudentListError(error)
        }
        refreshControl.endRefreshing()
    }

    private func applySnapshot(_ items: [StudentListItem]) {
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(items.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: true)
        updateEmptyState(isEmpty: items.isEmpty)
    }

    private func updateEmptyState(isEmpty: Bool) {
        let isSearching = !(searchController.searchBar.text ?? "").isEmpty
        emptyTitleLabel.text = isSearching ? "No Results" : "No Students"
        emptyMessageLabel.text = isSearching ? "Try a different name, phone, class, or school." : "Tap Add to create your first student."
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    private func showDeleteConfirmation(for item: StudentListItem) {
        let alert = UIAlertController(
            title: "Delete Student?",
            message: "This permanently removes \(item.fullName).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteStudent(id: item.id)
        })
        present(alert, animated: true)
    }

    private func archiveStudent(id: UUID) {
        do {
            applySnapshot(try viewModel.archiveStudent(id: id))
        } catch {
            showStudentListError(error)
        }
    }

    private func deleteStudent(id: UUID) {
        do {
            applySnapshot(try viewModel.deleteStudent(id: id))
        } catch {
            showStudentListError(error)
        }
    }

    private func showStudentListError(_ error: Error) {
        let alert = UIAlertController(
            title: "Unable to Update Students",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func addStudentTapped() {
        let addViewController = AddStudentViewController(viewModel: viewModel.makeAddStudentViewModel())
        addViewController.onSave = { [weak self] in
            self?.loadStudents()
        }
        let navigationController = UINavigationController(rootViewController: addViewController)
        present(navigationController, animated: true)
    }

    @objc private func refreshStudents() {
        loadStudents()
    }
}

extension StudentListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        do {
            let detailViewController = StudentDetailViewController(
                viewModel: try viewModel.studentDetailViewModel(for: item)
            )
            detailViewController.onChange = { [weak self] in
                self?.loadStudents()
            }
            navigationController?.pushViewController(detailViewController, animated: true)
        } catch {
            showStudentListError(error)
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard
            let studentID = dataSource.itemIdentifier(for: indexPath),
            let item = itemsByID[studentID]
        else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.showDeleteConfirmation(for: item)
            completion(true)
        }

        let archiveAction = UIContextualAction(style: .normal, title: "Archive") { [weak self] _, _, completion in
            self?.archiveStudent(id: studentID)
            completion(true)
        }
        archiveAction.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [deleteAction, archiveAction])
    }
}

extension StudentListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applySnapshot(viewModel.updateSearchText(searchController.searchBar.text ?? ""))
    }
}
