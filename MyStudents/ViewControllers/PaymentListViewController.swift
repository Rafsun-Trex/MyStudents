import UIKit

/// Lists every payment for the selected month, with a status filter and a
/// month stepper. Each row routes into the Collect Payment screen.
final class PaymentListViewController: UIViewController {
    private enum CellID {
        static let payment = "PaymentRowCell"
    }

    private let viewModel: PaymentListViewModel
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var rowsByID: [UUID: PaymentListRow] = [:]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = PaymentListHeaderView()
    private let filterControl = UISegmentedControl(items: PaymentListFilter.allCases.map(\.title))
    private let emptyStateLabel = UILabel()
    private let refreshControl = UIRefreshControl()

    init(viewModel: PaymentListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create PaymentListViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .never
        configureNavigation()
        configureTableView()
        configureHeader()
        configureEmptyState()
        configureDataSource()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func configureNavigation() {
        let previous = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(previousMonthTapped)
        )
        previous.accessibilityLabel = "Previous month"
        let next = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: self,
            action: #selector(nextMonthTapped)
        )
        next.accessibilityLabel = "Next month"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus.circle"),
                style: .plain,
                target: self,
                action: #selector(generateTapped)
            ),
            next,
            previous
        ]
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(PaymentRowCell.self, forCellReuseIdentifier: CellID.payment)
        tableView.estimatedRowHeight = 84
        tableView.rowHeight = UITableView.automaticDimension
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

    private func configureHeader() {
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        filterControl.selectedSegmentIndex = viewModel.filter.rawValue
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [headerView, filterControl])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        sizeTableHeader(to: container)
    }

    private func sizeTableHeader(to header: UIView) {
        tableView.tableHeaderView = header
        header.setNeedsLayout()
        header.layoutIfNeeded()
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        let size = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        )
        header.frame.size.height = size.height
        tableView.tableHeaderView = header
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let target = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(target).height
        if header.frame.height != height {
            header.frame.size.height = height
            tableView.tableHeaderView = header
        }
    }

    private func configureEmptyState() {
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = .preferredFont(forTextStyle: .body)
        emptyStateLabel.adjustsFontForContentSizeCategory = true
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, UUID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, id in
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.payment, for: indexPath) as! PaymentRowCell
            if let row = self?.rowsByID[id] {
                cell.configure(with: row)
            }
            return cell
        }
    }

    private func reload() {
        do {
            let rows = try viewModel.reload()
            apply(rows)
        } catch {
            showError(error)
        }
        refreshControl.endRefreshing()
    }

    private func apply(_ rows: [PaymentListRow]) {
        rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(rows.map(\.id))

        let existing = Set(dataSource.snapshot().itemIdentifiers)
        let reconfigured = rows.map(\.id).filter(existing.contains)
        if !reconfigured.isEmpty {
            snapshot.reconfigureItems(reconfigured)
        }
        dataSource.apply(snapshot, animatingDifferences: true)

        headerView.configure(monthTitle: viewModel.monthTitle, count: rows.count)
        updateEmptyState(isEmpty: rows.isEmpty)
    }

    private func updateEmptyState(isEmpty: Bool) {
        emptyStateLabel.text = isEmpty ? "No payments match this filter.\nTap + to generate monthly fees." : nil
        emptyStateLabel.isHidden = !isEmpty
    }

    // MARK: - Actions

    @objc private func refreshTriggered() {
        reload()
    }

    @objc private func previousMonthTapped() {
        do {
            apply(try viewModel.goToPreviousMonth())
        } catch {
            showError(error)
        }
    }

    @objc private func nextMonthTapped() {
        do {
            apply(try viewModel.goToNextMonth())
        } catch {
            showError(error)
        }
    }

    @objc private func filterChanged() {
        guard let newFilter = PaymentListFilter(rawValue: filterControl.selectedSegmentIndex) else { return }
        do {
            apply(try viewModel.setFilter(newFilter))
        } catch {
            showError(error)
        }
    }

    @objc private func generateTapped() {
        let confirm = UIAlertController(
            title: "Generate Monthly Fees",
            message: "Create bills for every active student×batch pair for \(viewModel.monthTitle)?",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Generate", style: .default) { [weak self] _ in
            self?.performGenerate()
        })
        present(confirm, animated: true)
    }

    private func performGenerate() {
        do {
            let (inserted, rows) = try viewModel.generateMonthlyFees()
            apply(rows)
            let alert = UIAlertController(
                title: inserted > 0 ? "Generated" : "Up to Date",
                message: inserted > 0
                    ? "Created \(inserted) new bill\(inserted == 1 ? "" : "s")."
                    : "All students already have a bill for \(viewModel.monthTitle).",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            showError(error)
        }
    }

    private func openCollect(for id: UUID) {
        do {
            let collectViewModel = try viewModel.makeCollectViewModel(forPaymentID: id)
            let viewController = CollectPaymentViewController(viewModel: collectViewModel)
            viewController.onChange = { [weak self] in
                self?.reload()
            }
            navigationController?.pushViewController(viewController, animated: true)
        } catch {
            showError(error)
        }
    }

    private func cancelPayment(_ id: UUID) {
        let confirm = UIAlertController(
            title: "Cancel Bill?",
            message: "The bill will be marked as cancelled and excluded from totals.",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: "Keep", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Cancel Bill", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                self.apply(try self.viewModel.cancelPayment(id: id))
            } catch {
                self.showError(error)
            }
        })
        present(confirm, animated: true)
    }
}

extension PaymentListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        openCollect(for: id)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let row = rowsByID[id]
        else { return nil }

        var actions: [UIContextualAction] = []
        if row.status != .paid && row.status != .cancelled {
            let collect = UIContextualAction(style: .normal, title: "Collect") { [weak self] _, _, completion in
                self?.openCollect(for: id)
                completion(true)
            }
            collect.backgroundColor = .systemGreen
            actions.append(collect)
        }
        if row.status != .cancelled {
            let cancelAction = UIContextualAction(style: .destructive, title: "Cancel") { [weak self] _, _, completion in
                self?.cancelPayment(id)
                completion(true)
            }
            actions.append(cancelAction)
        }
        return actions.isEmpty ? nil : UISwipeActionsConfiguration(actions: actions)
    }
}

// MARK: - Header

private final class PaymentListHeaderView: UIView {
    private let monthLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(monthTitle: String, count: Int) {
        monthLabel.text = monthTitle
        countLabel.text = "\(count) payment\(count == 1 ? "" : "s")"
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        monthLabel.font = .preferredFont(forTextStyle: .title3)
        monthLabel.adjustsFontForContentSizeCategory = true

        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = .secondaryLabel
        countLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [monthLabel, countLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - Cell

private final class PaymentRowCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let batchLabel = UILabel()
    private let dateLabel = UILabel()
    private let dueLabel = UILabel()
    private let paidLabel = UILabel()
    private let statusBadge = PaymentStatusBadge()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: PaymentListRow) {
        nameLabel.text = row.studentName
        batchLabel.text = row.batchName
        dateLabel.text = row.dateSubtitle
        statusBadge.configure(with: row.status)

        switch row.status {
        case .paid:
            dueLabel.text = "Paid \(row.paid)"
            dueLabel.textColor = .label
            paidLabel.text = "Expected \(row.expected)"
        case .partial:
            dueLabel.text = "Due \(row.due)"
            dueLabel.textColor = PaymentStatus.partial.color
            paidLabel.text = "Paid \(row.paid) of \(row.expected)"
        case .pending, .overdue:
            dueLabel.text = "Due \(row.due)"
            dueLabel.textColor = row.status.color
            paidLabel.text = "Expected \(row.expected)"
        case .cancelled:
            dueLabel.text = "—"
            dueLabel.textColor = .secondaryLabel
            paidLabel.text = "Expected \(row.expected)"
        }
    }

    private func setup() {
        accessoryType = .disclosureIndicator

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1

        batchLabel.translatesAutoresizingMaskIntoConstraints = false
        batchLabel.font = .preferredFont(forTextStyle: .caption1)
        batchLabel.adjustsFontForContentSizeCategory = true
        batchLabel.textColor = .secondaryLabel
        batchLabel.numberOfLines = 1

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .preferredFont(forTextStyle: .caption2)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .tertiaryLabel
        dateLabel.numberOfLines = 1

        dueLabel.translatesAutoresizingMaskIntoConstraints = false
        dueLabel.font = .preferredFont(forTextStyle: .headline)
        dueLabel.adjustsFontForContentSizeCategory = true
        dueLabel.textAlignment = .right
        dueLabel.setContentHuggingPriority(.required, for: .horizontal)
        dueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        paidLabel.translatesAutoresizingMaskIntoConstraints = false
        paidLabel.font = .preferredFont(forTextStyle: .caption2)
        paidLabel.adjustsFontForContentSizeCategory = true
        paidLabel.textColor = .secondaryLabel
        paidLabel.textAlignment = .right
        paidLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [nameLabel, batchLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = UIStackView(arrangedSubviews: [dueLabel, paidLabel, statusBadge])
        rightStack.axis = .vertical
        rightStack.spacing = 2
        rightStack.alignment = .trailing
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [textStack, rightStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }
}
