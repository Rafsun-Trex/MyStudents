import ObjectiveC
import UIKit

extension UIViewController {
    private enum AssociatedKeys {
        static var keyboardDismissDelegate: UInt8 = 0
    }

    /// Adds a tap gesture that dismisses the keyboard when the user taps anywhere
    /// outside of an active text input. Taps that land on a control, text field, or
    /// text view are ignored so those elements keep receiving their own touches,
    /// and `cancelsTouchesInView` is disabled so table rows still register taps
    /// (allowing the keyboard to be dismissed while scrolling search results).
    func hideKeyboardWhenTappedAround() {
        let delegate = KeyboardDismissGestureDelegate()
        objc_setAssociatedObject(
            self,
            &AssociatedKeys.keyboardDismissDelegate,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboardFromTap)
        )
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = delegate
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboardFromTap() {
        view.endEditing(true)
    }
}

private final class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var current = touch.view
        while let view = current {
            if view is UIControl || view is UITextField || view is UITextView {
                return false
            }
            current = view.superview
        }
        return true
    }
}

extension UIScrollView {
    /// Keeps text inputs visible above the keyboard by adjusting the scroll
    /// view's bottom inset and scrolling the focused field into view. Selector
    /// based observers are removed automatically when the scroll view deallocates.
    func enableKeyboardInsetAdjustment() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustInsetsForKeyboard(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetInsetsForKeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func adjustInsetsForKeyboard(_ notification: Notification) {
        guard
            let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else {
            return
        }

        let keyboardFrameInScrollView = convert(endFrame, from: nil)
        let overlap = bounds.intersection(keyboardFrameInScrollView).height

        contentInset.bottom = overlap
        verticalScrollIndicatorInsets.bottom = overlap

        if let responder = findFirstResponder() {
            let responderFrame = responder.convert(responder.bounds, to: self)
            scrollRectToVisible(responderFrame.insetBy(dx: 0, dy: -12), animated: true)
        }
    }

    @objc private func resetInsetsForKeyboard() {
        contentInset.bottom = 0
        verticalScrollIndicatorInsets.bottom = 0
    }
}

private extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.findFirstResponder() {
                return responder
            }
        }
        return nil
    }
}
