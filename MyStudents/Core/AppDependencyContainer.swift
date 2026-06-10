import Foundation
import os

final class AppDependencyContainer {
    let cloudSyncConfiguration: CloudSyncConfiguration
    let coreDataStack: CoreDataStack
    let persistenceService: PersistenceServiceProtocol
    let cloudSyncService: CloudSyncServiceProtocol

    private lazy var dashboardRepository: DashboardRepositoryProtocol = CoreDataDashboardRepository(
        persistenceService: persistenceService
    )

    private lazy var studentRepository: StudentRepositoryProtocol = CoreDataStudentRepository(
        persistenceService: persistenceService
    )

    private lazy var batchRepository: BatchRepositoryProtocol = CoreDataBatchRepository(
        persistenceService: persistenceService
    )

    private lazy var attendanceRepository: AttendanceRepositoryProtocol = CoreDataAttendanceRepository(
        persistenceService: persistenceService
    )

    private lazy var financeRepository: FinanceRepositoryProtocol = CoreDataFinanceRepository(
        persistenceService: persistenceService
    )

    init(cloudSyncConfiguration: CloudSyncConfiguration = .disabled) {
        self.cloudSyncConfiguration = cloudSyncConfiguration
        self.coreDataStack = CoreDataStack(cloudSyncConfiguration: cloudSyncConfiguration)
        self.persistenceService = CoreDataPersistenceService(coreDataStack: coreDataStack)
        self.cloudSyncService = CloudKitSyncService(configuration: cloudSyncConfiguration)
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(repository: dashboardRepository)
    }

    func makeStudentsViewModel() -> StudentsViewModel {
        StudentsViewModel(repository: studentRepository)
    }

    func makeBatchesViewModel() -> BatchesViewModel {
        BatchesViewModel(repository: batchRepository)
    }

    func makeAttendanceViewModel() -> AttendanceViewModel {
        AttendanceViewModel(repository: attendanceRepository)
    }

    func makeFinanceViewModel() -> FinanceViewModel {
        FinanceViewModel(repository: financeRepository)
    }

    func makeMoreViewModel() -> MoreViewModel {
        MoreViewModel()
    }

    func saveContext() {
        do {
            try persistenceService.saveViewContext()
        } catch {
            AppLogger.coreData.error("Failed to save Core Data context: \(error.localizedDescription, privacy: .public)")
        }
    }
}
