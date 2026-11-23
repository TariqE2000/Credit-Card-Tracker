import SwiftUI

/// Decides what the app shows: onboarding until the user confirms their cards, then the home screen.
struct RootView: View {
    @StateObject private var store = OnboardingStore()

    var body: some View {
        Group {
            if store.hasFinishedOnboarding {
                HomePlaceholderView()
            } else {
                OnboardingFlow()
            }
        }
        .environmentObject(store)
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}
