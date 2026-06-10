import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MyStudents"

    static let coreData = Logger(subsystem: subsystem, category: "CoreData")
    static let navigation = Logger(subsystem: subsystem, category: "Navigation")
}
