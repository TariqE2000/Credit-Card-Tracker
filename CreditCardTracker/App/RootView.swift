import SwiftUI

/// Decides what the app shows. The onboarding flow plugs in here in the next pull requests.
struct RootView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                AppLogo()
                Text("Credit Card Tracker")
                    .font(.app(22, .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}

#Preview("Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}
