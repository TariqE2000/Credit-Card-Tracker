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

    /// Screens that must not be left with a swipe. See `swipeBackDisabled()`.
    let lockedPages = NSHashTable<UIViewController>.weakObjects()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow going back when there is a screen to go back to. At the first screen the gesture
        // would start and then freeze the app.
        var responder: UIResponder? = gestureRecognizer.view
        while let current = responder {
            if let navigationController = current as? UINavigationController {
                guard navigationController.viewControllers.count > 1 else { return false }
                if let top = navigationController.topViewController, lockedPages.contains(top) {
                    return false
                }
                return true
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

// MARK: - A screen with no way back

/// Used on the review screen: it has no back button, and swiping back is turned off too.
extension View {
    func swipeBackDisabled() -> some View {
        background(SwipeBackLock().frame(width: 0, height: 0))
    }
}

private struct SwipeBackLock: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackLockController {
        SwipeBackLockController()
    }

    func updateUIViewController(_ controller: SwipeBackLockController, context: Context) {}
}

/// Sits inside a screen. While that screen is showing, swiping back is turned off.
private final class SwipeBackLockController: UIViewController {
    private weak var lockedPage: UIViewController?
    private weak var lockedNavigationController: UINavigationController?
    private var contentSwipeWasEnabled: Bool?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let navigationController else { return }
        lockedNavigationController = navigationController

        // The screen is the child of the navigation controller that holds this view controller.
        var page: UIViewController = self
        while let parent = page.parent, parent !== navigationController {
            page = parent
        }
        lockedPage = page
        EdgeSwipeBackDelegate.shared.lockedPages.add(page)

        // iOS 26 also lets people swipe back from anywhere on the screen.
        if #available(iOS 26.0, *), let recognizer = navigationController.interactiveContentPopGestureRecognizer {
            contentSwipeWasEnabled = recognizer.isEnabled
            recognizer.isEnabled = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let lockedPage {
            EdgeSwipeBackDelegate.shared.lockedPages.remove(lockedPage)
        }
        if #available(iOS 26.0, *),
           let wasEnabled = contentSwipeWasEnabled,
           let recognizer = lockedNavigationController?.interactiveContentPopGestureRecognizer {
            recognizer.isEnabled = wasEnabled
        }
        contentSwipeWasEnabled = nil
    }
}
