import UIKit

extension UIViewController {
    func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Something Went Wrong",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
