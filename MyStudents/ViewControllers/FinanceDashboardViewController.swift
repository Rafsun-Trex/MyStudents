import UIKit

/// Top-level finance screen. Shows the selected month's totals, a small
/// 6-month revenue chart, and the most recent collections, with shortcuts into
/// the payment list filtered by status.
final class FinanceDashboardViewController: UIViewController {
    private let viewModel: FinanceDashboardViewModel

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let monthLabel = UILabel()
    private let metricsGrid = UIStackView()
    private var metricCards: [FinanceMetricCard] = []

    private let revenueCard = FinanceRevenueCard()
    private let recentCard = FinanceRecentPaymentsCard()

    private let emptyStateView = EmptyStateView()

    init(viewModel: FinanceDashboardViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create FinanceDashboardViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .automatic
        configureNavigation()
        configureLayout()
        configureCards()
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
        navigationItem.leftBarButtonItems = [previous]
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: self,
                action: #selector(menuTapped)
            ),
            next
        ]
    }

    private func configureLayout() {
        view.backgroundColor = .systemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureCards() {
        monthLabel.font = .preferredFont(forTextStyle: .title2)
        monthLabel.adjustsFontForContentSizeCategory = true
        contentStack.addArrangedSubview(monthLabel)

        metricsGrid.axis = .vertical
        metricsGrid.spacing = 12
        contentStack.addArrangedSubview(metricsGrid)

        let viewAllButton = UIButton(type: .system)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        viewAllButton.setTitle("View All Payments", for: .normal)
        viewAllButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        viewAllButton.backgroundColor = .systemBlue
        viewAllButton.tintColor = .white
        viewAllButton.setTitleColor(.white, for: .normal)
        viewAllButton.layer.cornerRadius = 12
        viewAllButton.layer.cornerCurve = .continuous
        viewAllButton.addTarget(self, action: #selector(viewAllPaymentsTapped), for: .touchUpInside)
        viewAllButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        contentStack.addArrangedSubview(viewAllButton)

        contentStack.addArrangedSubview(revenueCard)
        contentStack.addArrangedSubview(recentCard)

        recentCard.onSelectPayment = { [weak self] paymentID in
            self?.openCollect(forPaymentID: paymentID)
        }
    }

    private func reload() {
        do {
            try viewModel.reload()
            applyState()
        } catch {
            showError(error)
        }
    }

    private func applyState() {
        monthLabel.text = viewModel.monthTitle
        layoutMetrics(viewModel.metrics())
        revenueCard.configure(with: viewModel.revenueBars())
        recentCard.configure(with: viewModel.recentRows())

        let hasData = viewModel.hasData
        scrollView.isHidden = !hasData
        emptyStateView.isHidden = hasData
        if !hasData {
            emptyStateView.configure(title: "No Bills for \(viewModel.monthTitle)")
        }
    }

    private func layoutMetrics(_ metrics: [FinanceDashboardMetric]) {
        metricsGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        metricCards.removeAll()

        let pairs = stride(from: 0, to: metrics.count, by: 2).map {
            Array(metrics[$0..<min($0 + 2, metrics.count)])
        }
        for pair in pairs {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            for metric in pair {
                let card = FinanceMetricCard()
                card.configure(with: metric)
                row.addArrangedSubview(card)
                metricCards.append(card)
            }
            if pair.count == 1 {
                let spacer = UIView()
                row.addArrangedSubview(spacer)
            }
            metricsGrid.addArrangedSubview(row)
        }
    }

    // MARK: - Actions

    @objc private func previousMonthTapped() {
        do {
            _ = try viewModel.goToPreviousMonth()
            applyState()
        } catch {
            showError(error)
        }
    }

    @objc private func nextMonthTapped() {
        do {
            _ = try viewModel.goToNextMonth()
            applyState()
        } catch {
            showError(error)
        }
    }

    @objc private func menuTapped() {
        let sheet = UIAlertController(
            title: viewModel.monthTitle,
            message: "Choose an action.",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "Generate Monthly Fees", style: .default) { [weak self] _ in
            self?.generateMonthlyFees()
        })
        sheet.addAction(UIAlertAction(title: "View All Payments", style: .default) { [weak self] _ in
            self?.viewAllPaymentsTapped()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let barButton = navigationItem.rightBarButtonItems?.first {
            sheet.popoverPresentationController?.barButtonItem = barButton
        }
        present(sheet, animated: true)
    }

    private func generateMonthlyFees() {
        do {
            let inserted = try viewModel.generateMonthlyFees()
            applyState()
            let title = inserted > 0 ? "Generated" : "Up to Date"
            let message = inserted > 0
                ? "Created \(inserted) new bill\(inserted == 1 ? "" : "s") for \(viewModel.monthTitle)."
                : "All students already have a bill for \(viewModel.monthTitle)."
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            showError(error)
        }
    }

    @objc private func viewAllPaymentsTapped() {
        openPaymentList(filter: .all)
    }

    private func openPaymentList(filter: PaymentListFilter) {
        let listViewModel = viewModel.makePaymentListViewModel(filter: filter)
        let viewController = PaymentListViewController(viewModel: listViewModel)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func openCollect(forPaymentID id: UUID) {
        do {
            let collectViewModel = try viewModel.makeCollectViewModel(forPaymentID: id)
            let viewController = CollectPaymentViewController(viewModel: collectViewModel)
            viewController.onChange = { [weak self] in
                self?.reload()
            }
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true)
        } catch {
            showError(error)
        }
    }
}

// MARK: - Metric Card

private final class FinanceMetricCard: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let accentBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with metric: FinanceDashboardMetric) {
        titleLabel.text = metric.title
        valueLabel.text = metric.value
        subtitleLabel.text = metric.subtitle
        accentBar.backgroundColor = metric.color
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.numberOfLines = 1

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 2

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.layer.cornerRadius = 2
        addSubview(accentBar)

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            stack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - Revenue Card

private final class FinanceRevenueCard: UIView {
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let barsStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with bars: [FinanceMonthRevenueBar]) {
        barsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !bars.isEmpty else {
            captionLabel.text = "No revenue data yet."
            return
        }
        let total = bars.reduce(NSDecimalNumber.zero) { $0.adding($1.collected) }
        captionLabel.text = "Collected \(FinanceFormatter.amount(total)) over the last \(bars.count) months."
        for bar in bars {
            let column = FinanceRevenueBarView()
            column.configure(with: bar)
            barsStack.addArrangedSubview(column)
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        titleLabel.text = "Monthly Revenue"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        captionLabel.font = .preferredFont(forTextStyle: .caption1)
        captionLabel.textColor = .secondaryLabel
        captionLabel.numberOfLines = 2
        captionLabel.adjustsFontForContentSizeCategory = true

        barsStack.axis = .horizontal
        barsStack.spacing = 8
        barsStack.distribution = .fillEqually
        barsStack.alignment = .bottom
        barsStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, captionLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(barsStack)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),

            barsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            barsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            barsStack.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            barsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            barsStack.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
}

private final class FinanceRevenueBarView: UIView {
    private let bar = UIView()
    private let label = UILabel()
    private let amountLabel = UILabel()
    private var heightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: FinanceMonthRevenueBar) {
        label.text = item.monthLabel
        amountLabel.text = NumberFormatter.compactAmount.string(from: item.collected) ?? ""
        let clamped = max(0.05, min(item.ratio, 1.0))
        heightConstraint?.constant = max(8, CGFloat(clamped) * 80)
        bar.backgroundColor = clamped > 0.05 ? UIColor.systemBlue : UIColor.systemGray4
    }

    private func setup() {
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = .systemBlue
        bar.layer.cornerRadius = 4
        bar.layer.cornerCurve = .continuous

        amountLabel.font = .preferredFont(forTextStyle: .caption2)
        amountLabel.textColor = .label
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textAlignment = .center

        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [amountLabel, bar, label])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        let height = bar.heightAnchor.constraint(equalToConstant: 40)
        heightConstraint = height
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            height
        ])
    }
}

private extension NumberFormatter {
    static let compactAmount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

// MARK: - Recent Payments Card

private final class FinanceRecentPaymentsCard: UIView {
    var onSelectPayment: ((UUID) -> Void)?

    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with rows: [FinanceDashboardRecentRow]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !rows.isEmpty
        stack.isHidden = rows.isEmpty
        for (index, row) in rows.enumerated() {
            let view = FinanceRecentPaymentRowView()
            view.configure(with: row, paymentID: row.id)
            view.onTap = { [weak self] id in self?.onSelectPayment?(id) }
            stack.addArrangedSubview(view)
            if index < rows.count - 1 {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stack.addArrangedSubview(separator)
            }
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        titleLabel.text = "Recent Collections"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        emptyLabel.text = "No payments collected for this month yet."
        emptyLabel.font = .preferredFont(forTextStyle: .footnote)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.isHidden = true

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIStackView(arrangedSubviews: [titleLabel, emptyLabel, stack])
        container.axis = .vertical
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }
}

private final class FinanceRecentPaymentRowView: UIControl {
    var onTap: ((UUID) -> Void)?

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusBadge = PaymentStatusBadge()
    private var paymentID: UUID = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: FinanceDashboardRecentRow, paymentID: UUID) {
        self.paymentID = paymentID
        nameLabel.text = row.studentName
        detailLabel.text = "\(row.batchName) • \(row.date)"
        amountLabel.text = row.amount
        statusBadge.configure(with: row.status)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true

        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 1

        amountLabel.font = .preferredFont(forTextStyle: .headline)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        let rightStack = UIStackView(arrangedSubviews: [amountLabel, statusBadge])
        rightStack.axis = .vertical
        rightStack.spacing = 2
        rightStack.alignment = .trailing
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [textStack, rightStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    @objc private func handleTap() {
        onTap?(paymentID)
    }
}

// MARK: - Shared badge

final class PaymentStatusBadge: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with status: PaymentStatus) {
        label.text = status.displayName.uppercased()
        label.textColor = status.color
        layer.borderColor = status.color.withAlphaComponent(0.4).cgColor
        backgroundColor = status.color.withAlphaComponent(0.12)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textAlignment = .center
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }
}
