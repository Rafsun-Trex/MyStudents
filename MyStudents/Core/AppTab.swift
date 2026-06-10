import Foundation

enum AppTab: CaseIterable {
    case dashboard
    case students
    case batches
    case attendance
    case finance
    case more

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .students:
            "Students"
        case .batches:
            "Batches"
        case .attendance:
            "Attendance"
        case .finance:
            "Finance"
        case .more:
            "More"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            "chart.bar"
        case .students:
            "person.3"
        case .batches:
            "rectangle.stack"
        case .attendance:
            "checkmark.circle"
        case .finance:
            "dollarsign.circle"
        case .more:
            "ellipsis.circle"
        }
    }

    var selectedSystemImageName: String {
        "\(systemImageName).fill"
    }
}
