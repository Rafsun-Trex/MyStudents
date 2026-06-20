import UIKit

final class AssignStudentsViewController: UIViewController {
    var onComplete: (() -> Void)?

    private let viewModel: AssignStudentsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)

    private var items: [AssignStudentItem] = []
    private var assignButton: UIBarButtonItem!

    init(viewModel: AssignStudentsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "AssignStudentsViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create AssignStudentsViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureTableView()
        configureEmptyState()
        configureSearch()
        hideKeyboardWhenTappedAround()
        loadStudents()
    }

    private func configureNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        assignButton = UIBarButtonItem(
            title: "Assign",
            style: .done,
            target: self,
            action: #selector(assignTapped)
        )
        navigationItem.rightBarButtonItem = assignButton
        updateAssignButtonState()
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AssignStudentCell")
        tableView.allowsMultipleSelection = true

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
        emptyTitleLabel.text = "No Students Available"
        emptyTitleLabel.font = .preferredFont(forTextStyle: .title2)
        emptyTitleLabel.adjustsFontForContentSizeCategory = true
        emptyTitleLabel.textAlignment = .center

        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.text = "Every active student is already in this batch."
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

    private func loadStudents() {
        do {
            items = try viewModel.loadStudents()
            tableView.reloadData()
            updateEmptyState()
            updateAssignButtonState()
        } catch {
            showError(error)
        }
    }

    private func updateEmptyState() {
        let isSearching = !(searchController.searchBar.text ?? "").isEmpty
        emptyTitleLabel.text = isSearching ? "No Results" : "No Students Available"
        emptyMessageLabel.text = isSearching
            ? "Try a different name, phone, class, or school."
            : "Every active student is already in this batch."
        emptyStateView.isHidden = !items.isEmpty
        tableView.isHidden = items.isEmpty
    }

    private func updateAssignButtonState() {
        assignButton.isEnabled = viewModel.hasSelection
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func assignTapped() {
        do {
            try viewModel.assignSelected()
            onComplete?()
            dismiss(animated: true)
        } catch {
            showError(error)
        }
    }
}

extension AssignStudentsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AssignStudentCell", for: indexPath)
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.fullName
        content.secondaryText = item.subtitle
        cell.contentConfiguration = content
        cell.accessoryType = item.isSelected ? .checkmark : .none
        return cell
    }
}

extension AssignStudentsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        viewModel.toggleSelection(id: item.id)
        items = viewModel.updateSearchText(searchController.searchBar.text ?? "")
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateAssignButtonState()
    }
}

extension AssignStudentsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        items = viewModel.updateSearchText(searchController.searchBar.text ?? "")
        tableView.reloadData()
        updateEmptyState()
    }
}
