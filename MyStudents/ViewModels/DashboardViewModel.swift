import CoreData
import Foundation
import UIKit

/// One stat card on the dashboard's compositional-layout grid.
struct DashboardCardItem {
    enum Kind: String, Hashable, CaseIterable, Sendable {
        case totalStudents
        case activeBatches
        case todaysClasses
        case duePayments
        case monthlyRevenue
    }

    enum Style: Hashable, Sendable {
        case compact
        case feature
    }

    let kind: Kind
    let title: String
    let value: String
    let subtitle: String
    let systemImageName: String
    let tintHex: String  // backing storage for the section's accent color
    let style: Style

    var tintColor: UIColor {
        UIColor(hex: tintHex) ?? .systemBlue
    }
}

final class DashboardViewModel: ScreenViewModel {
    let title = AppTab.dashboard.title

    private let repository: DashboardRepositoryProtocol
    private let calendar: Calendar
    private(set) var summary: DashboardSummary = .empty

    init(repository: DashboardRepositoryProtocol, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    var managedObjectContext: NSManagedObjectContext {
        repository.managedObjectContext
    }

    var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }

    var todayLabel: String {
        DashboardFormatter.headerDate.string(from: Date())
    }

    func reload() throws {
        summary = try repository.fetchSummary()
    }

    func cards() -> [DashboardCardItem] {
        [
            DashboardCardItem(
                kind: .totalStudents,
                title: "Total Students",
                value: "\(summary.totalStudents)",
                subtitle: summary.totalStudents == 1 ? "Enrolled student" : "Enrolled students",
                systemImageName: "person.3.fill",
                tintHex: "#4F46E5",
                style: .compact
            ),
            DashboardCardItem(
                kind: .activeBatches,
                title: "Active Batches",
                value: "\(summary.activeBatches)",
                subtitle: summary.activeBatches == 1 ? "Running batch" : "Running batches",
                systemImageName: "rectangle.stack.fill",
                tintHex: "#0EA5E9",
                style: .compact
            ),
            DashboardCardItem(
                kind: .todaysClasses,
                title: "Today's Classes",
                value: "\(summary.todaysClasses)",
                subtitle: summary.todaysClasses == 0
                    ? "No attendance yet"
                    : "Batches marked today",
                systemImageName: "calendar.badge.clock",
                tintHex: "#16A34A",
                style: .compact
            ),
            DashboardCardItem(
                kind: .duePayments,
                title: "Due Payments",
                value: "\(summary.duePayments)",
                subtitle: summary.duePayments == 0
                    ? "All settled this month"
                    : "Awaiting collection",
                systemImageName: "exclamationmark.circle.fill",
                tintHex: "#F97316",
                style: .compact
            ),
            DashboardCardItem(
                kind: .monthlyRevenue,
                title: "Monthly Revenue",
                value: DashboardFormatter.amount(summary.monthlyRevenue),
                subtitle: monthlyRevenueSubtitle(),
                systemImageName: "chart.line.uptrend.xyaxis",
                tintHex: "#7C3AED",
                style: .feature
            )
        ]
    }

    /// The tab a card opens when tapped, or nil if the card has no target.
    func destinationTab(for kind: DashboardCardItem.Kind) -> AppTab {
        switch kind {
        case .totalStudents: .students
        case .activeBatches: .batches
        case .todaysClasses: .attendance
        case .duePayments, .monthlyRevenue: .finance
        }
    }

    private func monthlyRevenueSubtitle() -> String {
        let expected = summary.monthlyExpected
        if expected.compare(NSDecimalNumber.zero) != .orderedDescending {
            return "Collected · \(DashboardFormatter.monthLabel.string(from: Date()))"
        }
        let percent = summary.monthlyRevenue
            .multiplying(by: NSDecimalNumber(value: 100))
            .dividing(by: expected)
        let percentInt = Int(truncating: percent)
        return "\(percentInt)% of \(DashboardFormatter.amount(expected)) expected"
    }
}

enum DashboardFormatter {
    static let headerDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let monthLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static func amount(_ value: NSDecimalNumber) -> String {
        NumberFormatter.financeAmount.string(from: value) ?? value.stringValue
    }
}

extension UIColor {
    /// Decodes 6-digit `#RRGGBB` strings used by `DashboardCardItem.tintHex`.
    convenience init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
