import UIKit

final class StudentFormView: UIScrollView {
    private let stackView = UIStackView()
    private let fullNameField = UITextField()
    private let guardianNameField = UITextField()
    private let phoneNumberField = UITextField()
    private let schoolField = UITextField()
    private let classNameField = UITextField()
    private let admissionDatePicker = UIDatePicker()
    private let monthlyFeeField = UITextField()
    private let notesTextView = UITextView()

    var formData: StudentFormData {
        StudentFormData(
            fullName: fullNameField.text ?? "",
            guardianName: guardianNameField.text ?? "",
            phoneNumber: phoneNumberField.text ?? "",
            school: schoolField.text ?? "",
            className: classNameField.text ?? "",
            admissionDate: admissionDatePicker.date,
            monthlyFee: Decimal(string: monthlyFeeField.text ?? "") ?? .zero,
            notes: notesTextView.text ?? ""
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

    func configure(with formData: StudentFormData) {
        fullNameField.text = formData.fullName
        guardianNameField.text = formData.guardianName
        phoneNumberField.text = formData.phoneNumber
        schoolField.text = formData.school
        classNameField.text = formData.className
        admissionDatePicker.date = formData.admissionDate
        monthlyFeeField.text = formData.monthlyFee == .zero ? "" : "\(formData.monthlyFee)"
        notesTextView.text = formData.notes
    }

    private func configure() {
        keyboardDismissMode = .interactive
        alwaysBounceVertical = true

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

        configureField(fullNameField, placeholder: "Full Name", contentType: .name, keyboardType: .default)
        configureField(guardianNameField, placeholder: "Guardian Name", contentType: .name, keyboardType: .default)
        configureField(phoneNumberField, placeholder: "Phone Number", contentType: .telephoneNumber, keyboardType: .phonePad)
        configureField(schoolField, placeholder: "School", contentType: .organizationName, keyboardType: .default)
        configureField(classNameField, placeholder: "Class", contentType: nil, keyboardType: .default)
        configureField(monthlyFeeField, placeholder: "Monthly Fee", contentType: nil, keyboardType: .decimalPad)

        admissionDatePicker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            admissionDatePicker.preferredDatePickerStyle = .compact
        }

        notesTextView.font = .preferredFont(forTextStyle: .body)
        notesTextView.adjustsFontForContentSizeCategory = true
        notesTextView.backgroundColor = .secondarySystemGroupedBackground
        notesTextView.layer.cornerRadius = 8
        notesTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        stackView.addArrangedSubview(fullNameField)
        stackView.addArrangedSubview(guardianNameField)
        stackView.addArrangedSubview(phoneNumberField)
        stackView.addArrangedSubview(schoolField)
        stackView.addArrangedSubview(classNameField)
        stackView.addArrangedSubview(makeDateRow())
        stackView.addArrangedSubview(monthlyFeeField)
        stackView.addArrangedSubview(makeSectionLabel("Notes"))
        stackView.addArrangedSubview(notesTextView)
    }

    private func configureField(
        _ textField: UITextField,
        placeholder: String,
        contentType: UITextContentType?,
        keyboardType: UIKeyboardType
    ) {
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.textContentType = contentType
        textField.keyboardType = keyboardType
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func makeDateRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.spacing = 12
        row.backgroundColor = .secondarySystemGroupedBackground
        row.layer.cornerRadius = 8
        row.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        row.isLayoutMarginsRelativeArrangement = true

        let label = UILabel()
        label.text = "Admission Date"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true

        row.addArrangedSubview(label)
        row.addArrangedSubview(admissionDatePicker)
        return row
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
