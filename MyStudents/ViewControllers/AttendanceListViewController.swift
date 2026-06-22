import CoreData
import UIKit

/// Lists every batch so the teacher can pick one and either take attendance for
/// that day or view its monthly report.
final class AttendanceListViewController: UIViewController {
    private enum CellID {
        static let batch = "AttendanceBatchCell"
    }

    private let viewModel: AttendanceViewModel
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: AttendanceBatchItem] = [:]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()
    private let refreshControl = UIRefreshControl()

    private var contextObserver: NSObjectProtocol?
    private var pendingReload = false

    init(viewModel: AttendanceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create AttendanceListViewController.")
    }

    deinit {
        if let observer = contextObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .automatic
        configureTableView()
        configureEmptyState()
        configureDataSource()
        observeContextChanges()
        loadBatches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBatches()
    }

    /// Re-fetches whenever the view context saves, so changes made in other
    /// tabs (e.g. a new batch in the Batches tab) appear without needing a tab
    /// switch. Reloads are coalesced through the main run loop to absorb
    /// bursts (assign-students, edit-batch, etc.).
    private func observeContextChanges() {
        guard contextObserver == nil else { return }
        let context = viewModel.managedObjectContext
        contextObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let savedContext = notification.object as? NSManagedObjectContext,
                savedContext === context || savedContext.parent === context
            else { return }
            self.scheduleReload()
        }
    }

    private func scheduleReload() {
        guard !pendingReload else { return }
        pendingReload = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingReload = false
            self.loadBatches()
        }
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellID.batch)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)

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
        emptyMessageLabel.text = "Create a batch to start tracking attendance."
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

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, UUID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, batchID in
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.batch, for: indexPath)
            guard let item = self?.itemsByID[batchID] else { return cell }
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            let studentText = "\(item.studentCount) student\(item.studentCount == 1 ? "" : "s")"
            content.secondaryText = "\(item.subtitle)\n\(studentText)"
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
            showError(error)
        }
        refreshControl.endRefreshing()
    }

    private func applySnapshot(_ items: [AttendanceBatchItem]) {
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ids = items.map(\.id)

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(ids)

        let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
        let reconfiguredIDs = ids.filter(existingIDs.contains)
        if !reconfiguredIDs.isEmpty {
            snapshot.reconfigureItems(reconfiguredIDs)
        }

        dataSource.apply(snapshot, animatingDifferences: true)
        updateEmptyState(isEmpty: items.isEmpty)
    }

    private func updateEmptyState(isEmpty: Bool) {
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    @objc private func refreshTriggered() {
        loadBatches()
    }

    private func presentActions(for item: AttendanceBatchItem) {
        let sheet = UIAlertController(
            title: item.name,
            message: "Choose what to do for this batch.",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "Take Attendance", style: .default) { [weak self] _ in
            self?.openTakeAttendance(for: item.id)
        })
        sheet.addAction(UIAlertAction(title: "Monthly Report", style: .default) { [weak self] _ in
            self?.openReport(for: item.id)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Anchor the popover to the row on iPad.
        if
            let index = dataSource.snapshot().indexOfItem(item.id),
            let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0))
        {
            sheet.popoverPresentationController?.sourceView = cell
            sheet.popoverPresentationController?.sourceRect = cell.bounds
        }

        present(sheet, animated: true)
    }

    private func openTakeAttendance(for id: UUID) {
        do {
            let viewModel = try viewModel.makeTakeAttendanceViewModel(forBatch: id)
            let viewController = TakeAttendanceViewController(viewModel: viewModel)
            viewController.onSaved = { [weak self] in
                self?.loadBatches()
            }
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            showError(error)
        }
    }

    private func openReport(for id: UUID) {
        do {
            let viewModel = try viewModel.makeReportViewModel(forBatch: id)
            let viewController = AttendanceReportViewController(viewModel: viewModel)
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            showError(error)
        }
    }
}

extension AttendanceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let item = itemsByID[id]
        else { return }
        presentActions(for: item)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }

        let reportAction = UIContextualAction(style: .normal, title: "Report") { [weak self] _, _, completion in
            self?.openReport(for: id)
            completion(true)
        }
        reportAction.backgroundColor = .systemIndigo

        let takeAction = UIContextualAction(style: .normal, title: "Take") { [weak self] _, _, completion in
            self?.openTakeAttendance(for: id)
            completion(true)
        }
        takeAction.backgroundColor = .systemGreen

        return UISwipeActionsConfiguration(actions: [takeAction, reportAction])
    }
}
