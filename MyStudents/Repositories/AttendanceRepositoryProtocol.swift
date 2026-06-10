import Foundation

protocol AttendanceRepositoryProtocol {
    func fetchAttendanceRecords() throws -> [AttendanceRecord]
    func fetchAttendanceRecords(forStudentID studentID: UUID) throws -> [AttendanceRecord]
}
