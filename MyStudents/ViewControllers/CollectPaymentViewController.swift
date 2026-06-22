import UIKit

/// Form for applying a payment to a single monthly bill. Supports partial
/// payments and lets the user pick a method, date, and notes. The current
/// status, expected, paid, and due figures are shown at the top of the screen.
final class CollectPaymentViewController: UIViewController {
    var onChange: (() -> Void)?

    private let viewModel: CollectPaymentViewModel

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let summaryCard = CollectPaymentSummaryCard()
    private let amountField = UITextField()
    private let dateField = UIDatePicker()
    private let methodControl = UISegmentedControl()
    private let notesField = UITextView()
    private let notesPlaceholder = UILabel()
    private let collectButton = UIButton(type: .system)
    private let cancelBillButton = UIButton(type: .system)

    private var methodOptions: [PaymentMethod] = [.cash, .bankTransfer, .mobileBanking, .card, .other]

    init(viewModel: CollectPaymentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create CollectPaymentViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .never
        configureNavigation()
        configureLayout()
        configureControls()
        configureKeyboardHandling()
        bind(snapshot: viewModel.snapshot())
    }

    private func configureNavigation() {
        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
        }
    }

    private func configureLayout() {
        view.backgroundColor = .systemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
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
    }

    private func configureControls() {
        contentStack.addArrangedSubview(summaryCard)

        contentStack.addArrangedSubview(sectionHeader("Amount"))
        amountField.translatesAutoresizingMaskIntoConstraints = false
        amountField.borderStyle = .roundedRect
        amountField.font = .preferredFont(forTextStyle: .title3)
        amountField.adjustsFontForContentSizeCategory = true
        amountField.keyboardType = .decimalPad
        amountField.placeholder = "0.00"
        amountField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        contentStack.addArrangedSubview(amountField)

        contentStack.addArrangedSubview(sectionHeader("Date"))
        dateField.translatesAutoresizingMaskIntoConstraints = false
        dateField.datePickerMode = .date
        dateField.preferredDatePickerStyle = .compact
        dateField.maximumDate = Date()
        dateField.date = Date()
        let dateContainer = inset(dateField)
        contentStack.addArrangedSubview(dateContainer)

        contentStack.addArrangedSubview(sectionHeader("Method"))
        methodControl.translatesAutoresizingMaskIntoConstraints = false
        methodControl.removeAllSegments()
        for (index, method) in methodOptions.enumerated() {
            methodControl.insertSegment(withTitle: method.displayName, at: index, animated: false)
        }
        methodControl.selectedSegmentIndex = 0
        contentStack.addArrangedSubview(methodControl)

        contentStack.addArrangedSubview(sectionHeader("Notes"))
        let notesContainer = UIView()
        notesContainer.translatesAutoresizingMaskIntoConstraints = false
        notesContainer.backgroundColor = .secondarySystemGroupedBackground
        notesContainer.layer.cornerRadius = 10
        notesContainer.layer.cornerCurve = .continuous

        notesField.translatesAutoresizingMaskIntoConstraints = false
        notesField.backgroundColor = .clear
        notesField.font = .preferredFont(forTextStyle: .body)
        notesField.adjustsFontForContentSizeCategory = true
        notesField.delegate = self

        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notesPlaceholder.text = "Optional notes"
        notesPlaceholder.font = .preferredFont(forTextStyle: .body)
        notesPlaceholder.textColor = .tertiaryLabel

        notesContainer.addSubview(notesField)
        notesContainer.addSubview(notesPlaceholder)
        NSLayoutConstraint.activate([
            notesField.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 10),
            notesField.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor, constant: -10),
            notesField.topAnchor.constraint(equalTo: notesContainer.topAnchor, constant: 8),
            notesField.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor, constant: -8),
            notesField.heightAnchor.constraint(equalToConstant: 90),

            notesPlaceholder.leadingAnchor.constraint(equalTo: notesField.leadingAnchor, constant: 5),
            notesPlaceholder.topAnchor.constraint(equalTo: notesField.topAnchor, constant: 8)
        ])
        contentStack.addArrangedSubview(notesContainer)

        collectButton.translatesAutoresizingMaskIntoConstraints = false
        collectButton.setTitle("Collect Payment", for: .normal)
        collectButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        collectButton.tintColor = .white
        collectButton.setTitleColor(.white, for: .normal)
        collectButton.backgroundColor = .systemGreen
        collectButton.layer.cornerRadius = 12
        collectButton.layer.cornerCurve = .continuous
        collectButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        collectButton.addTarget(self, action: #selector(collectTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(collectButton)

        cancelBillButton.translatesAutoresizingMaskIntoConstraints = false
        cancelBillButton.setTitle("Cancel Bill", for: .normal)
        cancelBillButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        cancelBillButton.tintColor = .systemRed
        cancelBillButton.addTarget(self, action: #selector(cancelBillTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(cancelBillButton)
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        return label
    }

    private func inset(_ view: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 10
        container.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        return container
    }

    private func configureKeyboardHandling() {
        hideKeyboardWhenTappedAround()
        scrollView.enableKeyboardInsetAdjustment()
    }

    private func bind(snapshot: CollectPaymentSnapshot) {
        summaryCard.configure(with: snapshot)
        notesField.text = snapshot.notes ?? ""
        notesPlaceholder.isHidden = !notesField.text.isEmpty
        if let method = snapshot.method, let index = methodOptions.firstIndex(of: method) {
            methodControl.selectedSegmentIndex = index
        }
        let suggested = snapshot.suggestedAmount
        if suggested.compare(NSDecimalNumber.zero) == .orderedDescending {
            amountField.text = formatPlainAmount(suggested)
        } else {
            amountField.text = ""
        }
        collectButton.isHidden = !snapshot.allowsCollection
        cancelBillButton.isHidden = snapshot.status == .cancelled
        amountField.isEnabled = snapshot.allowsCollection
        methodControl.isEnabled = snapshot.allowsCollection
        dateField.isEnabled = snapshot.allowsCollection
        notesField.isEditable = snapshot.allowsCollection
    }

    private func formatPlainAmount(_ value: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value) ?? value.stringValue
    }

    // MARK: - Actions

    @objc private func collectTapped() {
        let method = methodOptions[max(0, methodControl.selectedSegmentIndex)]
        let notes = notesField.text
        do {
            try viewModel.collect(
                amountText: amountField.text ?? "",
                date: dateField.date,
                method: method,
                notes: notes
            )
            onChange?()
            bind(snapshot: viewModel.snapshot())
            confirmAndDismiss(message: "Payment recorded.")
        } catch {
            showError(error)
        }
    }

    @objc private func cancelBillTapped() {
        let confirm = UIAlertController(
            title: "Cancel This Bill?",
            message: "It will be marked as cancelled and excluded from totals.",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: "Keep", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Cancel Bill", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try self.viewModel.cancel()
                self.onChange?()
                self.bind(snapshot: self.viewModel.snapshot())
                self.confirmAndDismiss(message: "Bill cancelled.")
            } catch {
                self.showError(error)
            }
        })
        present(confirm, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func confirmAndDismiss(message: String) {
        let alert = UIAlertController(title: "Done", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            if self.navigationController?.viewControllers.first === self {
                self.dismiss(animated: true)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        })
        present(alert, animated: true)
    }
}

extension CollectPaymentViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
    }
}

// MARK: - Summary card

private final class CollectPaymentSummaryCard: UIView {
    private let studentLabel = UILabel()
    private let detailLabel = UILabel()
    private let expectedRow = AmountRow(title: "Expected")
    private let paidRow = AmountRow(title: "Paid")
    private let dueRow = AmountRow(title: "Due", emphasis: true)
    private let statusBadge = PaymentStatusBadge()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with snapshot: CollectPaymentSnapshot) {
        studentLabel.text = snapshot.studentName
        detailLabel.text = "\(snapshot.batchName) • \(snapshot.monthTitle)"
        expectedRow.amount = snapshot.expected
        paidRow.amount = snapshot.paid
        dueRow.amount = snapshot.due
        dueRow.tint = snapshot.status.color
        statusBadge.configure(with: snapshot.status)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        studentLabel.font = .preferredFont(forTextStyle: .title3)
        studentLabel.adjustsFontForContentSizeCategory = true
        studentLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [studentLabel, detailLabel])
        header.axis = .vertical
        header.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [header, statusBadge])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let amounts = UIStackView(arrangedSubviews: [expectedRow, paidRow, dueRow])
        amounts.axis = .vertical
        amounts.spacing = 6

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        let container = UIStackView(arrangedSubviews: [topRow, separator, amounts])
        container.axis = .vertical
        container.spacing = 12
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

private final class AmountRow: UIView {
    var amount: String = "" { didSet { amountLabel.text = amount } }
    var tint: UIColor = .label { didSet { amountLabel.textColor = tint } }

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()

    init(title: String, emphasis: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = emphasis
            ? .preferredFont(forTextStyle: .headline)
            : .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = emphasis ? .label : .secondaryLabel

        amountLabel.font = emphasis
            ? .preferredFont(forTextStyle: .title3)
            : .preferredFont(forTextStyle: .subheadline)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
