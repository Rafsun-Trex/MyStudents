import UIKit
import os

final class MainTabBarController: UITabBarController {
    private var isConfigured = false

    func configure(with dependencyContainer: AppDependencyContainer) {
        guard !isConfigured else { return }

        viewControllers = AppTab.allCases.map { tab in
            let rootViewController = makeRootViewController(
                for: tab,
                dependencyContainer: dependencyContainer
            )
            let navigationController = UINavigationController(rootViewController: rootViewController)
            configure(navigationController, for: tab)
            return navigationController
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

    private func makeRootViewController(
        for tab: AppTab,
        dependencyContainer: AppDependencyContainer
    ) -> UIViewController {
        switch tab {
        case .dashboard:
            let viewController = DashboardViewController(nibName: "DashboardViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeDashboardViewModel()
            return viewController
        case .students:
            return StudentListViewController(viewModel: dependencyContainer.makeStudentsViewModel())
        case .batches:
            let viewController = BatchesViewController(nibName: "BatchesViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeBatchesViewModel()
            return viewController
        case .attendance:
            let viewController = AttendanceViewController(nibName: "AttendanceViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeAttendanceViewModel()
            return viewController
        case .finance:
            let viewController = FinanceViewController(nibName: "FinanceViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeFinanceViewModel()
            return viewController
        case .more:
            let viewController = MoreViewController(nibName: "MoreViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeMoreViewModel()
            return viewController
        }
    }
}
