import UIKit

final class BatchListViewController: UIViewController {
    private let viewModel: BatchesViewModel
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: BatchListItem] = [:]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private let refreshControl = UIRefreshControl()

    init(viewModel: BatchesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "BatchListViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create BatchListViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        configureNavigation()
        configureTableView()
        configureEmptyState()
        configureSearch()
        configureDataSource()
        hideKeyboardWhenTappedAround()
        loadBatches()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .automatic
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(createBatchTapped)
        )
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BatchCell")
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshBatches), for: .valueChanged)

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
        emptyTitleLabel.text = "No Batches"
        emptyTitleLabel.font = .preferredFont(forTextStyle: .title2)
        emptyTitleLabel.adjustsFontForContentSizeCategory = true
        emptyTitleLabel.textAlignment = .center

        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.text = "Tap Add to create your first batch."
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
        searchController.searchBar.placeholder = "Search batches"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, UUID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, batchID in
            let cell = tableView.dequeueReusableCell(withIdentifier: "BatchCell", for: indexPath)
            guard let item = self?.itemsByID[batchID] else { return cell }
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            content.secondaryText = "\(item.subtitle)\n\(item.detail)"
            content.secondaryTextProperties.numberOfLines = 2
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    private func loadBatches() {
        do {
            applySnapshot(try viewModel.loadBatches())
        } catch {
            showBatchListError(error)
        }
        refreshControl.endRefreshing()
    }

    private func applySnapshot(_ items: [BatchListItem]) {
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ids = items.map(\.id)

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(ids)

        // Rows are identified by a stable UUID, so editing a batch leaves the
        // identifier unchanged and the cell would not refresh on its own.
        // Reconfigure already-visible rows so edited values are reflected.
        let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
        let reconfiguredIDs = ids.filter(existingIDs.contains)
        if !reconfiguredIDs.isEmpty {
            snapshot.reconfigureItems(reconfiguredIDs)
        }

        dataSource.apply(snapshot, animatingDifferences: true)
        updateEmptyState(isEmpty: items.isEmpty)
    }

    private func updateEmptyState(isEmpty: Bool) {
        let isSearching = !(searchController.searchBar.text ?? "").isEmpty
        emptyTitleLabel.text = isSearching ? "No Results" : "No Batches"
        emptyMessageLabel.text = isSearching
            ? "Try a different name, subject, or schedule."
            : "Tap Add to create your first batch."
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    private func showDeleteConfirmation(for item: BatchListItem) {
        let alert = UIAlertController(
            title: "Delete Batch?",
            message: "This permanently removes \(item.name). Students will not be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteBatch(id: item.id)
        })
        present(alert, animated: true)
    }

    private func deleteBatch(id: UUID) {
        do {
            applySnapshot(try viewModel.deleteBatch(id: id))
        } catch {
            showBatchListError(error)
        }
    }

    private func showBatchListError(_ error: Error) {
        let alert = UIAlertController(
            title: "Unable to Update Batches",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func createBatchTapped() {
        let createViewController = CreateBatchViewController(viewModel: viewModel.makeCreateBatchViewModel())
        createViewController.showsCancelButton = true
        createViewController.onSave = { [weak self] in
            self?.loadBatches()
        }
        let navigationController = UINavigationController(rootViewController: createViewController)
        present(navigationController, animated: true)
    }

    @objc private func refreshBatches() {
        loadBatches()
    }
}

extension BatchListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }

        do {
            let detailViewController = BatchDetailViewController(
                viewModel: try viewModel.batchDetailViewModel(for: id)
            )
            detailViewController.onChange = { [weak self] in
                self?.loadBatches()
            }
            navigationController?.pushViewController(detailViewController, animated: true)
        } catch {
            showBatchListError(error)
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard
            let batchID = dataSource.itemIdentifier(for: indexPath),
            let item = itemsByID[batchID]
        else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.showDeleteConfirmation(for: item)
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

extension BatchListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applySnapshot(viewModel.updateSearchText(searchController.searchBar.text ?? ""))
    }
}
