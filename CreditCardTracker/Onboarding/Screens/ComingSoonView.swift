import SwiftUI

/// Stand-in for onboarding screens that arrive in later pull requests. It disappears once the last screen is in.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton()
            Spacer()
            Text(title)
                .font(.app(28, .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("This screen comes in a later pull request.")
                .font(.app(15))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
