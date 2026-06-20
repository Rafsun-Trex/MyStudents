import UIKit

/// Bulk attendance entry: every active student in the batch is shown with a
/// Present / Absent / Late segment, plus header counts, a date picker, and
/// "mark all" shortcuts.
final class TakeAttendanceViewController: UIViewController {
    private enum CellID {
        static let student = "TakeAttendanceStudentCell"
    }

    private let viewModel: TakeAttendanceViewModel
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: TakeAttendanceStudentItem] = [:]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = TakeAttendanceHeaderView()
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()

    var onSaved: (() -> Void)?

    init(viewModel: TakeAttendanceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create TakeAttendanceViewController.")
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
        loadAttendance()
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )

        let markAllPresent = UIAction(title: "Mark all Present") { [weak self] _ in
            self?.applyBulk(.present)
        }
        let markAllAbsent = UIAction(title: "Mark all Absent") { [weak self] _ in
            self?.applyBulk(.absent)
        }
        let markAllLate = UIAction(title: "Mark all Late") { [weak self] _ in
            self?.applyBulk(.late)
        }
        let menu = UIMenu(title: "Bulk Actions", children: [markAllPresent, markAllAbsent, markAllLate])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: menu
        )
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(TakeAttendanceCell.self, forCellReuseIdentifier: CellID.student)
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 84
        tableView.rowHeight = UITableView.automaticDimension

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.batchName = viewModel.batchName
        headerView.onDateChanged = { [weak self] newDate in
            self?.dateChanged(to: newDate)
        }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            headerView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            headerView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
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
        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(targetSize).height
        if header.frame.height != height {
            header.frame.size.height = height
            tableView.tableHeaderView = header
        }
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
        emptyMessageLabel.text = "Assign students to this batch first, then return to take attendance."
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
        ) { [weak self] tableView, indexPath, studentID in
            guard let self else {
                return tableView.dequeueReusableCell(withIdentifier: CellID.student, for: indexPath)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.student, for: indexPath) as! TakeAttendanceCell
            if let item = self.itemsByID[studentID] {
                cell.configure(with: item)
                cell.onStatusChanged = { [weak self] status in
                    self?.setStatus(status, forStudent: studentID)
                }
                cell.onClear = { [weak self] in
                    self?.clearStatus(forStudent: studentID)
                }
            }
            return cell
        }
    }

    private func loadAttendance() {
        do {
            applySnapshot(try viewModel.loadAttendance())
        } catch {
            showError(error)
        }
    }

    private func applySnapshot(_ items: [TakeAttendanceStudentItem]) {
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

        headerView.update(date: viewModel.date, summary: viewModel.summary())
        updateEmptyState(isEmpty: items.isEmpty)
    }

    private func updateEmptyState(isEmpty: Bool) {
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
    }

    private func setStatus(_ status: AttendanceStatus, forStudent id: UUID) {
        let items = viewModel.setStatus(status, forStudent: id)
        applySnapshot(items)
    }

    private func clearStatus(forStudent id: UUID) {
        let items = viewModel.clearStatus(forStudent: id)
        applySnapshot(items)
    }

    private func applyBulk(_ status: AttendanceStatus) {
        let items = viewModel.applyToAll(status)
        applySnapshot(items)
    }

    private func dateChanged(to date: Date) {
        do {
            applySnapshot(try viewModel.updateDate(date))
        } catch {
            showError(error)
        }
    }

    @objc private func saveTapped() {
        do {
            try viewModel.save()
            onSaved?()
            let alert = UIAlertController(
                title: "Attendance Saved",
                message: "Your changes for \(viewModel.formattedDate) have been recorded.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            present(alert, animated: true)
        } catch {
            showError(error)
        }
    }
}

// MARK: - Header View

private final class TakeAttendanceHeaderView: UIView {
    var batchName: String = "" {
        didSet { batchLabel.text = batchName }
    }

    var onDateChanged: ((Date) -> Void)?

    private let batchLabel = UILabel()
    private let datePicker = UIDatePicker()
    private let summaryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(date: Date, summary: TakeAttendanceSummary) {
        datePicker.date = date
        summaryLabel.attributedText = TakeAttendanceHeaderView.makeSummaryText(summary)
    }

    private func setup() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        batchLabel.translatesAutoresizingMaskIntoConstraints = false
        batchLabel.font = .preferredFont(forTextStyle: .headline)
        batchLabel.adjustsFontForContentSizeCategory = true
        batchLabel.numberOfLines = 0

        let dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.text = "Date"
        dateLabel.font = .preferredFont(forTextStyle: .subheadline)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .secondaryLabel

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.numberOfLines = 0
        summaryLabel.font = .preferredFont(forTextStyle: .footnote)
        summaryLabel.adjustsFontForContentSizeCategory = true

        let dateRow = UIStackView(arrangedSubviews: [dateLabel, datePicker])
        dateRow.translatesAutoresizingMaskIntoConstraints = false
        dateRow.axis = .horizontal
        dateRow.spacing = 12
        dateRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [batchLabel, dateRow, summaryLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    @objc private func dateChanged() {
        onDateChanged?(datePicker.date)
    }

    private static func makeSummaryText(_ summary: TakeAttendanceSummary) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let parts: [(String, UIColor)] = [
            ("Total \(summary.total)", .label),
            ("Present \(summary.present)", AttendanceStatus.present.color),
            ("Absent \(summary.absent)", AttendanceStatus.absent.color),
            ("Late \(summary.late)", AttendanceStatus.late.color),
            ("Unmarked \(summary.unmarked)", .secondaryLabel)
        ]
        for (index, (text, color)) in parts.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(
                    string: "  •  ",
                    attributes: [.foregroundColor: UIColor.tertiaryLabel]
                ))
            }
            result.append(NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: color,
                    .font: UIFont.preferredFont(forTextStyle: .footnote)
                ]
            ))
        }
        return result
    }
}

// MARK: - Cell

private final class TakeAttendanceCell: UITableViewCell {
    var onStatusChanged: ((AttendanceStatus) -> Void)?
    var onClear: (() -> Void)?

    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: AttendanceStatus.markable.map(\.displayName))
    private let clearButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onStatusChanged = nil
        onClear = nil
    }

    func configure(with item: TakeAttendanceStudentItem) {
        nameLabel.text = item.fullName
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = item.subtitle.isEmpty

        if let status = item.status, let index = AttendanceStatus.markable.firstIndex(of: status) {
            segmentedControl.selectedSegmentIndex = index
            segmentedControl.selectedSegmentTintColor = status.color
        } else {
            segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
            segmentedControl.selectedSegmentTintColor = nil
        }

        clearButton.isHidden = item.status == nil
    }

    private func setup() {
        selectionStyle = .none

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.setContentHuggingPriority(.required, for: .vertical)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = .tertiaryLabel
        clearButton.accessibilityLabel = "Clear status"
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.setContentHuggingPriority(.required, for: .horizontal)

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, clearButton])
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 8
        nameRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [nameRow, subtitleLabel, segmentedControl])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    @objc private func segmentChanged() {
        let index = segmentedControl.selectedSegmentIndex
        guard AttendanceStatus.markable.indices.contains(index) else { return }
        let status = AttendanceStatus.markable[index]
        segmentedControl.selectedSegmentTintColor = status.color
        onStatusChanged?(status)
    }

    @objc private func clearTapped() {
        onClear?()
    }
}
