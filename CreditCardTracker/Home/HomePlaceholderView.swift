import SwiftUI

/// Stand-in until the home screen is designed. Shown after "Confirm and finish".
struct HomePlaceholderView: View {
    @EnvironmentObject private var store: OnboardingStore

    private var cardCountText: String {
        store.cards.count == 1 ? "1 card" : "\(store.cards.count) cards"
    }

    var body: some View {
        VStack(spacing: 12) {
            AppLogo(size: 56)
                .padding(.bottom, 8)
            Text("You're all set")
                .font(.app(28, .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Tracking \(cardCountText). The home screen comes next.")
                .font(.app(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview("Home placeholder") {
    HomePlaceholderView()
        .environmentObject(OnboardingStore())
}
