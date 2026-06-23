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
            return DashboardViewController(viewModel: dependencyContainer.makeDashboardViewModel())
        case .students:
            return StudentListViewController(viewModel: dependencyContainer.makeStudentsViewModel())
        case .batches:
            return BatchListViewController(viewModel: dependencyContainer.makeBatchesViewModel())
        case .attendance:
            return AttendanceListViewController(viewModel: dependencyContainer.makeAttendanceViewModel())
        case .finance:
            return FinanceDashboardViewController(
                viewModel: dependencyContainer.makeFinanceDashboardViewModel()
            )
        case .more:
            let viewController = MoreViewController(nibName: "MoreViewController", bundle: nil)
            viewController.viewModel = dependencyContainer.makeMoreViewModel()
            return viewController
        }
    }
}
