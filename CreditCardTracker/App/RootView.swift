import SwiftUI

/// Decides what the app shows. For now that is always the onboarding flow.
struct RootView: View {
    @StateObject private var store = OnboardingStore()

    var body: some View {
        OnboardingFlow()
            .environmentObject(store)
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}
