import SwiftUI

/// "Continue with Google" / "Continue with Apple" button, also used on the log in screen.
struct SocialSignInButton: View {
    let provider: AuthProvider
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                Text(title)
            }
        }
        .buttonStyle(.secondary)
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .medium))
                .accessibilityHidden(true)
        case .google:
            // Placeholder. TODO: swap for the official Google "G" asset when Google Sign-In is added,
            // as Google's branding rules require.
            Text("G")
                .font(.app(18, .bold))
                .accessibilityHidden(true)
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: 12) {
        SocialSignInButton(provider: .google, title: "Continue with Google") {}
        SocialSignInButton(provider: .apple, title: "Continue with Apple") {}
    }
    .padding(24)
    .background(Theme.background)
}
