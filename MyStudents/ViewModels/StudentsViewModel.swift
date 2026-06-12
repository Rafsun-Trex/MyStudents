import Foundation

struct StudentFormData {
    var fullName: String
    var guardianName: String
    var phoneNumber: String
    var school: String
    var className: String
    var admissionDate: Date
    var monthlyFee: Decimal
    var notes: String

    static var empty: StudentFormData {
        StudentFormData(
            fullName: "",
            guardianName: "",
            phoneNumber: "",
            school: "",
            className: "",
            admissionDate: Date(),
            monthlyFee: .zero,
            notes: ""
        )
    }
}

struct StudentListItem {
    let id: UUID
    let fullName: String
    let subtitle: String
    let detail: String
    let isArchived: Bool
}

final class StudentsViewModel: ScreenViewModel {
    let title = AppTab.students.title

    private let repository: StudentRepositoryProtocol
    private(set) var students: [Student] = []
    private var searchText = ""

    init(repository: StudentRepositoryProtocol) {
        self.repository = repository
    }

    func loadStudents() throws -> [StudentListItem] {
        students = try repository.fetchStudents(includeArchived: false)
        return filteredItems()
    }

    func updateSearchText(_ text: String) -> [StudentListItem] {
        searchText = text
        return filteredItems()
    }

    func studentDetailViewModel(for id: UUID) throws -> StudentDetailViewModel {
        guard let student = try repository.student(withID: id) else {
            throw StudentRepositoryError.studentNotFound
        }

        return StudentDetailViewModel(student: student, repository: repository)
    }

    func makeAddStudentViewModel() -> AddStudentViewModel {
        AddStudentViewModel(repository: repository)
    }

    func archiveStudent(id: UUID) throws -> [StudentListItem] {
        try repository.archiveStudent(id: id)
        return try loadStudents()
    }

    func deleteStudent(id: UUID) throws -> [StudentListItem] {
        try repository.deleteStudent(id: id)
        return try loadStudents()
    }

    private func filteredItems() -> [StudentListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredStudents: [Student]

        if query.isEmpty {
            filteredStudents = students
        } else {
            filteredStudents = students.filter { student in
                [
                    student.fullName,
                    student.guardianName,
                    student.phoneNumber,
                    student.school,
                    student.className
                ]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(query) }
            }
        }

        return filteredStudents.map(StudentListItem.init)
    }
}

final class AddStudentViewModel {
    let title = "Add Student"
    private let repository: StudentRepositoryProtocol

    init(repository: StudentRepositoryProtocol) {
        self.repository = repository
    }

    func save(formData: StudentFormData) throws {
        try validate(formData)
        try repository.addStudent(formData)
    }
}

final class EditStudentViewModel {
    let title = "Edit Student"
    private let studentID: UUID
    private let repository: StudentRepositoryProtocol

    let initialFormData: StudentFormData

    init(student: Student, repository: StudentRepositoryProtocol) {
        self.studentID = student.id
        self.repository = repository
        self.initialFormData = StudentFormData(student: student)
    }

    func save(formData: StudentFormData) throws {
        try validate(formData)
        try repository.updateStudent(id: studentID, with: formData)
    }
}

final class StudentDetailViewModel {
    private let studentID: UUID
    private let repository: StudentRepositoryProtocol

    private(set) var detail: StudentDetailData

    init(student: Student, repository: StudentRepositoryProtocol) {
        self.studentID = student.id
        self.repository = repository
        self.detail = StudentDetailData(student: student)
    }

    func reload() throws -> StudentDetailData {
        guard let student = try repository.student(withID: studentID) else {
            throw StudentRepositoryError.studentNotFound
        }

        detail = StudentDetailData(student: student)
        return detail
    }

    func makeEditStudentViewModel() throws -> EditStudentViewModel {
        guard let student = try repository.student(withID: studentID) else {
            throw StudentRepositoryError.studentNotFound
        }

        return EditStudentViewModel(student: student, repository: repository)
    }

    func archiveStudent() throws {
        try repository.archiveStudent(id: studentID)
    }

    func deleteStudent() throws {
        try repository.deleteStudent(id: studentID)
    }
}

struct StudentDetailData {
    let id: UUID
    let fullName: String
    let guardianName: String
    let phoneNumber: String
    let school: String
    let className: String
    let admissionDate: String
    let monthlyFee: String
    let notes: String
    let isArchived: Bool
}

private extension StudentListItem {
    nonisolated init(student: Student) {
        let subtitleParts = [student.className, student.school]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        self.init(
            id: student.id,
            fullName: student.fullName,
            subtitle: subtitleParts.isEmpty ? "No class or school added" : subtitleParts.joined(separator: " • "),
            detail: student.phoneNumber ?? "No phone number",
            isArchived: student.isArchived
        )
    }
}

private extension StudentFormData {
    init(student: Student) {
        self.init(
            fullName: student.fullName,
            guardianName: student.guardianName ?? "",
            phoneNumber: student.phoneNumber ?? "",
            school: student.school ?? "",
            className: student.className ?? "",
            admissionDate: student.admissionDate,
            monthlyFee: student.monthlyFee.decimalValue,
            notes: student.notes ?? ""
        )
    }
}

private extension StudentDetailData {
    init(student: Student) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.maximumFractionDigits = 2

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        self.init(
            id: student.id,
            fullName: student.fullName,
            guardianName: student.guardianName ?? "Not added",
            phoneNumber: student.phoneNumber ?? "Not added",
            school: student.school ?? "Not added",
            className: student.className ?? "Not added",
            admissionDate: dateFormatter.string(from: student.admissionDate),
            monthlyFee: currencyFormatter.string(from: student.monthlyFee) ?? "\(student.monthlyFee.decimalValue)",
            notes: student.notes ?? "No notes",
            isArchived: student.isArchived
        )
    }
}

private func validate(_ formData: StudentFormData) throws {
    if formData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw StudentValidationError.fullNameRequired
    }
}

enum StudentValidationError: LocalizedError {
    case fullNameRequired

    var errorDescription: String? {
        switch self {
        case .fullNameRequired:
            "Student name is required."
        }
    }
}
