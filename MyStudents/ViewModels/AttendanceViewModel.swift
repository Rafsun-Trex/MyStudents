import UIKit

extension AttendanceStatus {
    /// Statuses offered when marking attendance, per the module requirements.
    static var markable: [AttendanceStatus] {
        [.present, .absent, .late]
    }

    var displayName: String {
        switch self {
        case .present: "Present"
        case .absent: "Absent"
        case .late: "Late"
        case .excused: "Excused"
        }
    }

    var shortName: String {
        switch self {
        case .present: "P"
        case .absent: "A"
        case .late: "L"
        case .excused: "E"
        }
    }

    var color: UIColor {
        switch self {
        case .present: .systemGreen
        case .absent: .systemRed
        case .late: .systemOrange
        case .excused: .systemGray
        }
    }
}

struct AttendanceBatchItem {
    let id: UUID
    let name: String
    let subtitle: String
    let studentCount: Int
}

final class AttendanceViewModel: ScreenViewModel {
    let title = AppTab.attendance.title

    private let repository: AttendanceRepositoryProtocol
    private(set) var batches: [Batch] = []

    init(repository: AttendanceRepositoryProtocol) {
        self.repository = repository
    }

    func loadBatches() throws -> [AttendanceBatchItem] {
        batches = try repository.fetchBatches()
        return batches.map(AttendanceBatchItem.init)
    }

    func makeTakeAttendanceViewModel(forBatch id: UUID) throws -> TakeAttendanceViewModel {
        guard let batch = try repository.batch(withID: id) else {
            throw AttendanceRepositoryError.batchNotFound
        }
        return TakeAttendanceViewModel(batch: batch, repository: repository)
    }

    func makeReportViewModel(forBatch id: UUID) throws -> AttendanceReportViewModel {
        guard let batch = try repository.batch(withID: id) else {
            throw AttendanceRepositoryError.batchNotFound
        }
        return AttendanceReportViewModel(batch: batch, repository: repository)
    }
}

private extension AttendanceBatchItem {
    init(batch: Batch) {
        let count = batch.students.filter { !$0.isArchived }.count
        let subtitleParts = [batch.subject, batch.schedule]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        self.init(
            id: batch.id,
            name: batch.name,
            subtitle: subtitleParts.isEmpty ? "No subject or schedule added" : subtitleParts.joined(separator: " • "),
            studentCount: count
        )
    }
}

// MARK: - Take Attendance

/// One row in the Take Attendance screen.
struct TakeAttendanceStudentItem {
    let id: UUID
    let fullName: String
    let subtitle: String
    let status: AttendanceStatus?
}

/// Header counts shown above the student list.
struct TakeAttendanceSummary {
    let total: Int
    let present: Int
    let absent: Int
    let late: Int
    let unmarked: Int
}

struct AttendanceValidationError: LocalizedError {
    let errorDescription: String?

    static let noStudents = AttendanceValidationError(
        errorDescription: "This batch has no active students to mark."
    )
    static let nothingMarked = AttendanceValidationError(
        errorDescription: "Mark at least one student before saving."
    )
}

final class TakeAttendanceViewModel {
    let batchName: String
    let title: String

    private let batchID: UUID
    private let repository: AttendanceRepositoryProtocol
    private let calendar: Calendar

    private(set) var students: [Student] = []
    private var statusByStudentID: [UUID: AttendanceStatus] = [:]
    private(set) var date: Date

    init(
        batch: Batch,
        repository: AttendanceRepositoryProtocol,
        calendar: Calendar = .current,
        initialDate: Date = Date()
    ) {
        self.batchID = batch.id
        self.batchName = batch.name
        self.title = "Take Attendance"
        self.repository = repository
        self.calendar = calendar
        self.date = calendar.startOfDay(for: initialDate)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Re-loads the student list and overlays any existing attendance for the
    /// currently selected date so the user sees what they previously saved.
    @discardableResult
    func loadAttendance() throws -> [TakeAttendanceStudentItem] {
        students = try repository.students(inBatch: batchID)
        let existing = try repository.attendanceRecords(forBatch: batchID, on: date)
        statusByStudentID = Dictionary(
            existing.compactMap { record -> (UUID, AttendanceStatus)? in
                guard let studentID = record.student?.id else { return nil }
                return (studentID, record.attendanceStatus)
            },
            uniquingKeysWith: { first, _ in first }
        )
        return makeItems()
    }

    @discardableResult
    func updateDate(_ newDate: Date) throws -> [TakeAttendanceStudentItem] {
        date = calendar.startOfDay(for: newDate)
        return try loadAttendance()
    }

    func setStatus(_ status: AttendanceStatus, forStudent id: UUID) -> [TakeAttendanceStudentItem] {
        statusByStudentID[id] = status
        return makeItems()
    }

    /// Bulk-applies the same status to every active student in the batch.
    func applyToAll(_ status: AttendanceStatus) -> [TakeAttendanceStudentItem] {
        for student in students {
            statusByStudentID[student.id] = status
        }
        return makeItems()
    }

    /// Removes the marking from one student without affecting others.
    func clearStatus(forStudent id: UUID) -> [TakeAttendanceStudentItem] {
        statusByStudentID.removeValue(forKey: id)
        return makeItems()
    }

    func summary() -> TakeAttendanceSummary {
        var counts: [AttendanceStatus: Int] = [:]
        for student in students {
            guard let status = statusByStudentID[student.id] else { continue }
            counts[status, default: 0] += 1
        }
        let present = counts[.present, default: 0]
        let absent = counts[.absent, default: 0]
        let late = counts[.late, default: 0]
        let marked = present + absent + late
        return TakeAttendanceSummary(
            total: students.count,
            present: present,
            absent: absent,
            late: late,
            unmarked: max(0, students.count - marked)
        )
    }

    func save() throws {
        guard !students.isEmpty else {
            throw AttendanceValidationError.noStudents
        }

        let entries: [AttendanceEntry] = students.compactMap { student in
            guard let status = statusByStudentID[student.id] else { return nil }
            return AttendanceEntry(studentID: student.id, status: status)
        }

        guard !entries.isEmpty else {
            throw AttendanceValidationError.nothingMarked
        }

        try repository.saveAttendance(entries, forBatch: batchID, on: date)
    }

    private func makeItems() -> [TakeAttendanceStudentItem] {
        students.map { student in
            TakeAttendanceStudentItem(
                id: student.id,
                fullName: student.fullName,
                subtitle: takeAttendanceSubtitle(for: student),
                status: statusByStudentID[student.id]
            )
        }
    }
}

// MARK: - Attendance Report

/// One day in the per-day attendance history.
struct AttendanceHistoryDay {
    let date: Date
    let formattedDate: String
    let present: Int
    let absent: Int
    let late: Int
    let total: Int
}

/// Per-student totals for the selected month.
struct AttendanceReportStudentRow {
    let id: UUID
    let fullName: String
    let present: Int
    let absent: Int
    let late: Int
    let attendanceRate: Double  // 0...1 over marked days
    let attendanceRateString: String
    let breakdownString: String
}

/// Aggregated month totals shown at the top of the report.
struct AttendanceReportSummary {
    let monthTitle: String
    let dayCount: Int
    let studentCount: Int
    let present: Int
    let absent: Int
    let late: Int
    let attendanceRateString: String
}

final class AttendanceReportViewModel {
    let batchName: String
    let title = "Attendance Report"

    private let batchID: UUID
    private let repository: AttendanceRepositoryProtocol
    private let calendar: Calendar

    private(set) var month: Date

    private var students: [Student] = []
    private var records: [AttendanceRecord] = []

    init(
        batch: Batch,
        repository: AttendanceRepositoryProtocol,
        calendar: Calendar = .current,
        initialMonth: Date = Date()
    ) {
        self.batchID = batch.id
        self.batchName = batch.name
        self.repository = repository
        self.calendar = calendar
        self.month = calendar.startOfMonth(for: initialMonth)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }

    /// Re-fetches data for the current `month` selection and returns the rebuilt
    /// summary so the screen can refresh in a single call.
    func reload() throws {
        students = try repository.students(inBatch: batchID)
        records = try repository.attendanceRecords(forBatch: batchID, inMonth: month)
    }

    @discardableResult
    func updateMonth(_ newMonth: Date) throws -> AttendanceReportSummary {
        month = calendar.startOfMonth(for: newMonth)
        try reload()
        return summary()
    }

    func goToPreviousMonth() throws -> AttendanceReportSummary {
        let previous = calendar.date(byAdding: .month, value: -1, to: month) ?? month
        return try updateMonth(previous)
    }

    func goToNextMonth() throws -> AttendanceReportSummary {
        let next = calendar.date(byAdding: .month, value: 1, to: month) ?? month
        return try updateMonth(next)
    }

    func summary() -> AttendanceReportSummary {
        let counts = counts(in: records)
        let totalMarked = counts.present + counts.absent + counts.late
        let dayCount = Set(records.map { calendar.startOfDay(for: $0.date) }).count

        return AttendanceReportSummary(
            monthTitle: monthTitle,
            dayCount: dayCount,
            studentCount: students.count,
            present: counts.present,
            absent: counts.absent,
            late: counts.late,
            attendanceRateString: percentageString(
                numerator: counts.present + counts.late,
                denominator: totalMarked
            )
        )
    }

    /// Per-student rows for the table, sorted by name.
    func studentRows() -> [AttendanceReportStudentRow] {
        let recordsByStudentID = Dictionary(grouping: records) { $0.student?.id }
        return students
            .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
            .map { student -> AttendanceReportStudentRow in
                let counts = counts(in: recordsByStudentID[student.id] ?? [])
                let marked = counts.present + counts.absent + counts.late
                let attendanceRate = marked == 0 ? 0 : Double(counts.present + counts.late) / Double(marked)
                return AttendanceReportStudentRow(
                    id: student.id,
                    fullName: student.fullName,
                    present: counts.present,
                    absent: counts.absent,
                    late: counts.late,
                    attendanceRate: attendanceRate,
                    attendanceRateString: percentageString(
                        numerator: counts.present + counts.late,
                        denominator: marked
                    ),
                    breakdownString: "P \(counts.present) • A \(counts.absent) • L \(counts.late)"
                )
            }
    }

    /// Per-day history rolled up across the batch, most recent first.
    func historyDays() -> [AttendanceHistoryDay] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { date, dayRecords -> AttendanceHistoryDay in
                let counts = counts(in: dayRecords)
                return AttendanceHistoryDay(
                    date: date,
                    formattedDate: formatter.string(from: date),
                    present: counts.present,
                    absent: counts.absent,
                    late: counts.late,
                    total: dayRecords.count
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func counts(in records: [AttendanceRecord]) -> (present: Int, absent: Int, late: Int) {
        var present = 0, absent = 0, late = 0
        for record in records {
            switch record.attendanceStatus {
            case .present: present += 1
            case .absent: absent += 1
            case .late: late += 1
            case .excused: break
            }
        }
        return (present, absent, late)
    }

    private func percentageString(numerator: Int, denominator: Int) -> String {
        guard denominator > 0 else { return "—" }
        let value = Double(numerator) / Double(denominator)
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}

private func takeAttendanceSubtitle(for student: Student) -> String {
    let parts = [student.className, student.school]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

    if !parts.isEmpty {
        return parts.joined(separator: " • ")
    }

    return student.phoneNumber ?? ""
}
