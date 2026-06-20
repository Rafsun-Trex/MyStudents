import UIKit

private nonisolated enum ReportSection: Hashable {
    case main
}

private nonisolated enum ReportRow: Hashable {
    case student(UUID)
    case history(Date)
}

/// Monthly attendance report for a batch. Two views (per-student totals and
/// per-day history) share the same fetched month, switched via a segmented
/// control. The user can step backward/forward a month at a time.
final class AttendanceReportViewController: UIViewController {
    private enum Mode: Int, CaseIterable {
        case students
        case history

        var title: String {
            switch self {
            case .students: "By Student"
            case .history: "By Day"
            }
        }
    }

    private enum CellID {
        static let student = "AttendanceReportStudentCell"
        static let history = "AttendanceReportHistoryCell"
    }

    private let viewModel: AttendanceReportViewModel
    private var dataSource: UITableViewDiffableDataSource<ReportSection, ReportRow>!
    private var studentRowsByID: [UUID: AttendanceReportStudentRow] = [:]
    private var historyDaysByDate: [Date: AttendanceHistoryDay] = [:]
    private var mode: Mode = .students

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = AttendanceReportHeaderView()
    private let modeControl = UISegmentedControl(items: Mode.allCases.map(\.title))
    private let emptyStateView = UIView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()

    init(viewModel: AttendanceReportViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create AttendanceReportViewController.")
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

        navigationItem.rightBarButtonItems = [next, previous]
    }

    private func configureTableView() {
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.register(AttendanceReportStudentCell.self, forCellReuseIdentifier: CellID.student)
        tableView.register(AttendanceReportHistoryCell.self, forCellReuseIdentifier: CellID.history)
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 64
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

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.selectedSegmentIndex = mode.rawValue
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [headerView, modeControl])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
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
        emptyTitleLabel.font = .preferredFont(forTextStyle: .title3)
        emptyTitleLabel.adjustsFontForContentSizeCategory = true
        emptyTitleLabel.textAlignment = .center

        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
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
        dataSource = UITableViewDiffableDataSource<ReportSection, ReportRow>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, row in
            guard let self else {
                return UITableViewCell()
            }

            switch row {
            case .student(let id):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.student, for: indexPath
                ) as! AttendanceReportStudentCell
                if let item = self.studentRowsByID[id] {
                    cell.configure(with: item)
                }
                return cell

            case .history(let date):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CellID.history, for: indexPath
                ) as! AttendanceReportHistoryCell
                if let item = self.historyDaysByDate[date] {
                    cell.configure(with: item)
                }
                return cell
            }
        }
    }

    private func reload() {
        do {
            try viewModel.reload()
            applyCurrentSnapshot()
        } catch {
            showError(error)
        }
    }

    private func applyCurrentSnapshot() {
        headerView.update(summary: viewModel.summary())

        var snapshot = NSDiffableDataSourceSnapshot<ReportSection, ReportRow>()
        snapshot.appendSections([.main])

        switch mode {
        case .students:
            let rows = viewModel.studentRows()
            studentRowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
            snapshot.appendItems(rows.map { ReportRow.student($0.id) })
            updateEmptyState(
                isEmpty: rows.isEmpty,
                title: "No Students",
                message: "Assign students to this batch to see attendance."
            )

        case .history:
            let days = viewModel.historyDays()
            historyDaysByDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
            snapshot.appendItems(days.map { ReportRow.history($0.date) })
            updateEmptyState(
                isEmpty: days.isEmpty,
                title: "No Records",
                message: "No attendance was recorded for this month yet."
            )
        }

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func updateEmptyState(isEmpty: Bool, title: String, message: String) {
        emptyTitleLabel.text = title
        emptyMessageLabel.text = message
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    @objc private func modeChanged() {
        guard let newMode = Mode(rawValue: modeControl.selectedSegmentIndex) else { return }
        mode = newMode
        applyCurrentSnapshot()
    }

    @objc private func previousMonthTapped() {
        do {
            _ = try viewModel.goToPreviousMonth()
            applyCurrentSnapshot()
        } catch {
            showError(error)
        }
    }

    @objc private func nextMonthTapped() {
        do {
            _ = try viewModel.goToNextMonth()
            applyCurrentSnapshot()
        } catch {
            showError(error)
        }
    }
}

extension AttendanceReportViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .secondarySystemGroupedBackground
    }
}

// MARK: - Header View

private final class AttendanceReportHeaderView: UIView {
    var batchName: String = "" {
        didSet { batchLabel.text = batchName }
    }

    private let batchLabel = UILabel()
    private let monthLabel = UILabel()
    private let summaryLabel = UILabel()
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(summary: AttendanceReportSummary) {
        monthLabel.text = summary.monthTitle
        summaryLabel.attributedText = AttendanceReportHeaderView.makeSummaryText(summary)
        metaLabel.text = AttendanceReportHeaderView.makeMetaText(summary)
    }

    private func setup() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        batchLabel.translatesAutoresizingMaskIntoConstraints = false
        batchLabel.font = .preferredFont(forTextStyle: .subheadline)
        batchLabel.adjustsFontForContentSizeCategory = true
        batchLabel.textColor = .secondaryLabel

        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        monthLabel.font = .preferredFont(forTextStyle: .title2)
        monthLabel.adjustsFontForContentSizeCategory = true

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.numberOfLines = 0
        summaryLabel.font = .preferredFont(forTextStyle: .footnote)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.numberOfLines = 0
        metaLabel.font = .preferredFont(forTextStyle: .footnote)
        metaLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [batchLabel, monthLabel, summaryLabel, metaLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    private static func makeSummaryText(_ summary: AttendanceReportSummary) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let parts: [(String, UIColor)] = [
            ("Present \(summary.present)", AttendanceStatus.present.color),
            ("Absent \(summary.absent)", AttendanceStatus.absent.color),
            ("Late \(summary.late)", AttendanceStatus.late.color)
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

    private static func makeMetaText(_ summary: AttendanceReportSummary) -> String {
        let dayPart = "\(summary.dayCount) day\(summary.dayCount == 1 ? "" : "s") marked"
        let studentPart = "\(summary.studentCount) student\(summary.studentCount == 1 ? "" : "s")"
        return "\(dayPart)  •  \(studentPart)  •  Attendance \(summary.attendanceRateString)"
    }
}

// MARK: - Per-Student Cell

private final class AttendanceReportStudentCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let breakdownLabel = UILabel()
    private let rateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: AttendanceReportStudentRow) {
        nameLabel.text = row.fullName
        breakdownLabel.text = row.breakdownString
        rateLabel.text = row.attendanceRateString

        if row.attendanceRate >= 0.9 {
            rateLabel.textColor = .systemGreen
        } else if row.attendanceRate >= 0.75 {
            rateLabel.textColor = .systemOrange
        } else if row.present + row.absent + row.late == 0 {
            rateLabel.textColor = .secondaryLabel
        } else {
            rateLabel.textColor = .systemRed
        }
    }

    private func setup() {
        selectionStyle = .none

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0

        breakdownLabel.translatesAutoresizingMaskIntoConstraints = false
        breakdownLabel.font = .preferredFont(forTextStyle: .footnote)
        breakdownLabel.adjustsFontForContentSizeCategory = true
        breakdownLabel.textColor = .secondaryLabel
        breakdownLabel.numberOfLines = 0

        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.font = .preferredFont(forTextStyle: .headline)
        rateLabel.adjustsFontForContentSizeCategory = true
        rateLabel.textAlignment = .right
        rateLabel.setContentHuggingPriority(.required, for: .horizontal)
        rateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, breakdownLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [textStack, rateLabel])
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

// MARK: - Per-Day Cell

private final class AttendanceReportHistoryCell: UITableViewCell {
    private let dateLabel = UILabel()
    private let breakdownLabel = UILabel()
    private let totalLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with day: AttendanceHistoryDay) {
        dateLabel.text = day.formattedDate
        breakdownLabel.attributedText = AttendanceReportHistoryCell.makeBreakdownText(day)
        totalLabel.text = "\(day.total)"
    }

    private func setup() {
        selectionStyle = .none

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .preferredFont(forTextStyle: .body)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.numberOfLines = 0

        breakdownLabel.translatesAutoresizingMaskIntoConstraints = false
        breakdownLabel.font = .preferredFont(forTextStyle: .footnote)
        breakdownLabel.adjustsFontForContentSizeCategory = true
        breakdownLabel.numberOfLines = 0

        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = .preferredFont(forTextStyle: .headline)
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.textAlignment = .right
        totalLabel.textColor = .secondaryLabel
        totalLabel.setContentHuggingPriority(.required, for: .horizontal)
        totalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [dateLabel, breakdownLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [textStack, totalLabel])
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

    private static func makeBreakdownText(_ day: AttendanceHistoryDay) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let parts: [(String, UIColor)] = [
            ("P \(day.present)", AttendanceStatus.present.color),
            ("A \(day.absent)", AttendanceStatus.absent.color),
            ("L \(day.late)", AttendanceStatus.late.color)
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
