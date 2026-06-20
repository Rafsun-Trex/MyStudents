import UIKit

final class BatchFormView: UIScrollView {
    private let stackView = UIStackView()
    private let nameField = UITextField()
    private let subjectField = UITextField()
    private let scheduleField = UITextField()
    private let feeField = UITextField()

    var formData: BatchFormData {
        BatchFormData(
            name: nameField.text ?? "",
            subject: subjectField.text ?? "",
            schedule: scheduleField.text ?? "",
            fee: Decimal(string: feeField.text ?? "") ?? .zero
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func configure(with formData: BatchFormData) {
        nameField.text = formData.name
        subjectField.text = formData.subject
        scheduleField.text = formData.schedule
        feeField.text = formData.fee == .zero ? "" : "\(formData.fee)"
    }

    private func configure() {
        keyboardDismissMode = .interactive
        alwaysBounceVertical = true
        enableKeyboardInsetAdjustment()

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 32, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        ])

        configureField(nameField, placeholder: "Batch Name", keyboardType: .default)
        configureField(subjectField, placeholder: "Subject", keyboardType: .default)
        configureField(scheduleField, placeholder: "Schedule (e.g. Mon, Wed 5 PM)", keyboardType: .default)
        configureField(feeField, placeholder: "Fee", keyboardType: .decimalPad)

        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(subjectField)
        stackView.addArrangedSubview(scheduleField)
        stackView.addArrangedSubview(feeField)
    }

    private func configureField(
        _ textField: UITextField,
        placeholder: String,
        keyboardType: UIKeyboardType
    ) {
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
}
