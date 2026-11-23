import SwiftUI

/// Decides what the app shows: onboarding until the user confirms their cards, then the home screen.
struct RootView: View {
    @StateObject private var store = OnboardingStore(catalog: CardCatalogStore.live())

    var body: some View {
        Group {
            if store.hasFinishedOnboarding {
                HomePlaceholderView()
            } else {
                OnboardingFlow()
            }
        }
        .environmentObject(store)
        // Downloads the card list in the background while the user signs up. Does nothing when the
        // list saved on the phone is already from the pinned release.
        .task {
            await store.catalog.load()
        }
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}
