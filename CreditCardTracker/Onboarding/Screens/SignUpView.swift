import SwiftUI

/// First screen: "Never forget to pay a card again."
struct SignUpView: View {
    @EnvironmentObject private var store: OnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 16) {
                AppLogo(size: 56)
                    .padding(.bottom, 8)

                Text("Never forget to pay a card again.")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("All your credit card balances and due dates, in one calm place.")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                SocialSignInButton(provider: .google, title: "Continue with Google") {
                    store.signIn(with: .google)
                }
                SocialSignInButton(provider: .apple, title: "Continue with Apple") {
                    store.signIn(with: .apple)
                }
            }

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                Button("Log in") {
                    store.showLogIn()
                }
                .buttonStyle(.textLink)
            }
            .padding(.top, 20)

            Text(termsText)
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
                .tint(Theme.accentText)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// "By continuing, you agree to our Terms and Privacy Policy." with both names as links.
    private var termsText: AttributedString {
        var text = AttributedString("By continuing, you agree to our Terms and Privacy Policy.")
        if let range = text.range(of: "Terms") {
            text[range].link = AppLinks.terms
        }
        if let range = text.range(of: "Privacy Policy") {
            text[range].link = AppLinks.privacyPolicy
        }
        return text
    }
}

#Preview("Sign up – light") {
    SignUpView()
        .environmentObject(OnboardingStore())
        .preferredColorScheme(.light)
}

#Preview("Sign up – dark") {
    SignUpView()
        .environmentObject(OnboardingStore())
        .preferredColorScheme(.dark)
}
