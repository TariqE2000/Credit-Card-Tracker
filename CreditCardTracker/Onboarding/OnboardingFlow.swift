import SwiftUI

/// The navigation stack for onboarding. Starts on the sign up screen; the store's `path` decides what is pushed on top.
struct OnboardingFlow: View {
    @EnvironmentObject private var store: OnboardingStore

    var body: some View {
        NavigationStack(path: $store.path) {
            SignUpView()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: OnboardingRoute) -> some View {
        switch route {
        case .logIn:
            LogInView()
        case .pickCards:
            ComingSoonView(title: "Pick your cards")
        case .cardForm, .editCard:
            ComingSoonView(title: "Card form")
        case .review:
            ComingSoonView(title: "Review cards")
        }
    }
}
