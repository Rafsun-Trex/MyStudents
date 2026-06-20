import Foundation

struct BatchFormData {
    var name: String
    var subject: String
    var schedule: String
    var fee: Decimal

    static var empty: BatchFormData {
        BatchFormData(name: "", subject: "", schedule: "", fee: .zero)
    }
}

struct BatchListItem {
    let id: UUID
    let name: String
    let subtitle: String
    let detail: String
}

struct BatchDetailData {
    let id: UUID
    let name: String
    let subject: String
    let schedule: String
    let fee: String
    let studentCount: Int
}

struct BatchStudentItem {
    let id: UUID
    let fullName: String
    let subtitle: String
}

struct AssignStudentItem {
    let id: UUID
    let fullName: String
    let subtitle: String
    let isSelected: Bool
}

final class BatchesViewModel: ScreenViewModel {
    let title = AppTab.batches.title

    private let repository: BatchRepositoryProtocol
    private(set) var batches: [Batch] = []
    private var searchText = ""

    init(repository: BatchRepositoryProtocol) {
        self.repository = repository
    }

    func loadBatches() throws -> [BatchListItem] {
        batches = try repository.fetchBatches()
        return filteredItems()
    }

    func updateSearchText(_ text: String) -> [BatchListItem] {
        searchText = text
        return filteredItems()
    }

    func makeCreateBatchViewModel() -> BatchFormViewModel {
        BatchFormViewModel(repository: repository)
    }

    func batchDetailViewModel(for id: UUID) throws -> BatchDetailViewModel {
        guard let batch = try repository.batch(withID: id) else {
            throw BatchRepositoryError.batchNotFound
        }

        return BatchDetailViewModel(batch: batch, repository: repository)
    }

    func deleteBatch(id: UUID) throws -> [BatchListItem] {
        try repository.deleteBatch(id: id)
        return try loadBatches()
    }

    private func filteredItems() -> [BatchListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredBatches: [Batch]

        if query.isEmpty {
            filteredBatches = batches
        } else {
            filteredBatches = batches.filter { batch in
                [batch.name, batch.subject, batch.schedule]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(query) }
            }
        }

        return filteredBatches.map(BatchListItem.init)
    }
}

final class BatchFormViewModel {
    let title: String
    let initialFormData: BatchFormData

    private let repository: BatchRepositoryProtocol
    private let batchID: UUID?

    init(repository: BatchRepositoryProtocol) {
        self.repository = repository
        self.batchID = nil
        self.title = "Create Batch"
        self.initialFormData = .empty
    }

    init(batch: Batch, repository: BatchRepositoryProtocol) {
        self.repository = repository
        self.batchID = batch.id
        self.title = "Edit Batch"
        self.initialFormData = BatchFormData(batch: batch)
    }

    func save(formData: BatchFormData) throws {
        try validate(formData)

        if let batchID {
            try repository.updateBatch(id: batchID, with: formData)
        } else {
            try repository.addBatch(formData)
        }
    }
}

final class BatchDetailViewModel {
    private let batchID: UUID
    private let repository: BatchRepositoryProtocol

    private(set) var detail: BatchDetailData
    private(set) var students: [BatchStudentItem] = []

    init(batch: Batch, repository: BatchRepositoryProtocol) {
        self.batchID = batch.id
        self.repository = repository
        self.detail = BatchDetailData(batch: batch)
    }

    func reload() throws -> BatchDetailData {
        guard let batch = try repository.batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        detail = BatchDetailData(batch: batch)
        return detail
    }

    func loadStudents() throws -> [BatchStudentItem] {
        students = try repository.students(inBatch: batchID).map(BatchStudentItem.init)
        return students
    }

    func makeEditBatchViewModel() throws -> BatchFormViewModel {
        guard let batch = try repository.batch(withID: batchID) else {
            throw BatchRepositoryError.batchNotFound
        }

        return BatchFormViewModel(batch: batch, repository: repository)
    }

    func makeAssignStudentsViewModel() -> AssignStudentsViewModel {
        AssignStudentsViewModel(batchID: batchID, repository: repository)
    }

    func removeStudent(id: UUID) throws -> [BatchStudentItem] {
        try repository.removeStudent(id, fromBatch: batchID)
        return try loadStudents()
    }

    func deleteBatch() throws {
        try repository.deleteBatch(id: batchID)
    }
}

final class AssignStudentsViewModel {
    let title = "Assign Students"

    private let batchID: UUID
    private let repository: BatchRepositoryProtocol
    private(set) var students: [Student] = []
    private var selectedIDs: Set<UUID> = []
    private var searchText = ""

    init(batchID: UUID, repository: BatchRepositoryProtocol) {
        self.batchID = batchID
        self.repository = repository
    }

    var hasSelection: Bool {
        !selectedIDs.isEmpty
    }

    func loadStudents() throws -> [AssignStudentItem] {
        students = try repository.availableStudents(forBatch: batchID)
        return filteredItems()
    }

    func updateSearchText(_ text: String) -> [AssignStudentItem] {
        searchText = text
        return filteredItems()
    }

    func toggleSelection(id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func isSelected(id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

    func assignSelected() throws {
        try repository.assignStudents(Array(selectedIDs), toBatch: batchID)
    }

    private func filteredItems() -> [AssignStudentItem] {
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

        return filteredStudents.map { student in
            AssignStudentItem(
                id: student.id,
                fullName: student.fullName,
                subtitle: studentSubtitle(for: student),
                isSelected: selectedIDs.contains(student.id)
            )
        }
    }
}

struct BatchValidationError: LocalizedError {
    let errorDescription: String?

    static let nameRequired = BatchValidationError(errorDescription: "Batch name is required.")
}

private func validate(_ formData: BatchFormData) throws {
    if formData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw BatchValidationError.nameRequired
    }
}

private func studentSubtitle(for student: Student) -> String {
    let parts = [student.className, student.school]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

    if !parts.isEmpty {
        return parts.joined(separator: " • ")
    }

    return student.phoneNumber ?? "No additional details"
}

private func batchCurrencyString(from value: NSDecimalNumber) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    return formatter.string(from: value) ?? "\(value.decimalValue)"
}

private extension BatchListItem {
    init(batch: Batch) {
        let subtitleParts = [batch.subject, batch.schedule]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        let count = batch.students.count
        let studentText = "\(count) student\(count == 1 ? "" : "s")"

        self.init(
            id: batch.id,
            name: batch.name,
            subtitle: subtitleParts.isEmpty ? "No subject or schedule added" : subtitleParts.joined(separator: " • "),
            detail: "\(studentText) • \(batchCurrencyString(from: batch.fee))"
        )
    }
}

private extension BatchDetailData {
    init(batch: Batch) {
        self.init(
            id: batch.id,
            name: batch.name,
            subject: batch.subject ?? "Not added",
            schedule: batch.schedule ?? "Not added",
            fee: batchCurrencyString(from: batch.fee),
            studentCount: batch.students.count
        )
    }
}

private extension BatchStudentItem {
    init(student: Student) {
        self.init(
            id: student.id,
            fullName: student.fullName,
            subtitle: studentSubtitle(for: student)
        )
    }
}

private extension BatchFormData {
    init(batch: Batch) {
        self.init(
            name: batch.name,
            subject: batch.subject ?? "",
            schedule: batch.schedule ?? "",
            fee: batch.fee.decimalValue
        )
    }
}
