import SwiftUI

/// "Welcome back" screen for people who already have an account.
struct LogInView: View {
    @EnvironmentObject private var store: OnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton()
                Spacer()
            }
            .padding(.top, 8)

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                AppLogo(size: 56)
                    .padding(.bottom, 8)

                Text("Welcome back")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Log in with the same account you used to sign up.")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                SocialSignInButton(provider: .google, title: "Log in with Google") {
                    store.signIn(with: .google)
                }
                SocialSignInButton(provider: .apple, title: "Log in with Apple") {
                    store.signIn(with: .apple)
                }
            }

            HStack(spacing: 4) {
                Text("New here?")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                Button("Create an account") {
                    store.showSignUp()
                }
                .buttonStyle(.textLink)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Log in – light") {
    NavigationStack {
        LogInView()
    }
    .environmentObject(OnboardingStore())
    .preferredColorScheme(.light)
}

#Preview("Log in – dark") {
    NavigationStack {
        LogInView()
    }
    .environmentObject(OnboardingStore())
    .preferredColorScheme(.dark)
}
