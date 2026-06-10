import UIKit
import os

final class MainTabBarController: UITabBarController {
    private var isConfigured = false

    func configure(with dependencyContainer: AppDependencyContainer) {
        guard !isConfigured else { return }

        let tabs = AppTab.allCases
        let navigationControllers = viewControllers?.compactMap { $0 as? UINavigationController } ?? []

        for (index, navigationController) in navigationControllers.enumerated() where index < tabs.count {
            let tab = tabs[index]
            configure(navigationController, for: tab)
            injectDependencies(
                into: navigationController.viewControllers.first,
                for: tab,
                dependencyContainer: dependencyContainer
            )
        }

        isConfigured = true
    }

    private func configure(_ navigationController: UINavigationController, for tab: AppTab) {
        navigationController.tabBarItem = UITabBarItem(
            title: tab.title,
            image: UIImage(systemName: tab.systemImageName),
            selectedImage: UIImage(systemName: tab.selectedSystemImageName)
        )
    }

    private func injectDependencies(
        into viewController: UIViewController?,
        for tab: AppTab,
        dependencyContainer: AppDependencyContainer
    ) {
        switch (tab, viewController) {
        case (.dashboard, let viewController as DashboardViewController):
            viewController.viewModel = dependencyContainer.makeDashboardViewModel()
        case (.students, let viewController as StudentsViewController):
            viewController.viewModel = dependencyContainer.makeStudentsViewModel()
        case (.batches, let viewController as BatchesViewController):
            viewController.viewModel = dependencyContainer.makeBatchesViewModel()
        case (.attendance, let viewController as AttendanceViewController):
            viewController.viewModel = dependencyContainer.makeAttendanceViewModel()
        case (.finance, let viewController as FinanceViewController):
            viewController.viewModel = dependencyContainer.makeFinanceViewModel()
        case (.more, let viewController as MoreViewController):
            viewController.viewModel = dependencyContainer.makeMoreViewModel()
        default:
            AppLogger.navigation.error("Missing dependency injection mapping for \(tab.title, privacy: .public)")
        }
    }
}
