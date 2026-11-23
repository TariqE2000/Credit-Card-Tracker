import SwiftUI
import UIKit

/// The "<" chevron at the top left of every screen except the first.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
    }
}

// Screens hide the system navigation bar to use their own header. Hiding the bar also turns off
// the swipe-from-the-left-edge "go back" gesture, so this puts it back.
//
// This delegate is given to the edge-swipe gesture only. An earlier version made UINavigationController
// itself the delegate and answered "yes" to every gesture it was asked about. On iOS 26 that includes the
// new swipe-anywhere "go back" gesture, which then took over vertical drags, so lists and forms on every
// pushed screen would not scroll.
private final class EdgeSwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = EdgeSwipeBackDelegate()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow going back when there is a screen to go back to. At the first screen the gesture
        // would start and then freeze the app.
        var responder: UIResponder? = gestureRecognizer.view
        while let current = responder {
            if let navigationController = current as? UINavigationController {
                return navigationController.viewControllers.count > 1
            }
            responder = current.next
        }
        return false
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = EdgeSwipeBackDelegate.shared
    }
}
