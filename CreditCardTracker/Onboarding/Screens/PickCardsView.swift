import SwiftUI

/// Where "Pick your cards" was opened from.
enum PickCardsMode {
    /// Right after signing up.
    case firstPick
    /// From "Add another card" on the review screen. The issuers the user already has cards from are
    /// ticked and cannot be unticked, but the counter can go up; the user ticks new issuers too.
    case addMore
}

/// "Pick your cards": search the issuers and tick every bank the user has a card from, setting how many
/// cards each one has.
struct PickCardsView: View {
    var mode: PickCardsMode = .firstPick

    @EnvironmentObject private var store: OnboardingStore
    @EnvironmentObject private var catalog: IssuerCatalogStore
    @State private var query = ""
    @State private var isRetrying = false

    private var results: [Issuer] {
        catalog.issuers(matching: query)
    }

    private var isLoadingFirstList: Bool {
        catalog.phase == .loading && catalog.issuers.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                BackButton()
                    .padding(.top, 8)

                Text("Who issued your cards?")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 12)

                Text("Pick each bank you have a credit card from. If you have two or more from the same bank, tap + to add them. You can add more later.")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                searchField
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)

            cardList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Pieces

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField(
                "",
                text: $query,
                prompt: Text("Search for a bank").foregroundStyle(Theme.textSecondary)
            )
            .font(.app(16))
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Theme.field,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if catalog.phase == .unavailable {
                    unavailableNotice
                }

                if isLoadingFirstList {
                    loadingNotice
                }

                ForEach(results) { issuer in
                    // Cards already added only count as locked on the second pick screen.
                    let lockedCount = mode == .addMore ? store.lockedCount(of: issuer) : 0
                    IssuerPickRow(
                        issuer: issuer,
                        count: store.count(of: issuer),
                        lockedCount: lockedCount,
                        onToggle: { store.toggleSelection(of: issuer) },
                        onIncrease: { store.increaseCount(of: issuer) },
                        onDecrease: { store.decreaseCount(of: issuer, minimum: lockedCount) }
                    )
                }

                if results.isEmpty && !isLoadingFirstList {
                    Text("No banks match “\(query)”.")
                        .font(.app(15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }

                if catalog.phase == .ready && !catalog.issuers.isEmpty {
                    creditLine
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 4)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Shown for the very first launch while the list downloads (a second or two on a normal connection).
    private var loadingNotice: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading banks…")
                .font(.app(15))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .accessibilityElement(children: .combine)
    }

    /// The download failed and nothing was saved, so only the built-in starter issuers are showing.
    private var unavailableNotice: some View {
        HStack(spacing: 12) {
            Text("Couldn't load the full list of banks. Showing popular ones.")
                .font(.app(13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(isRetrying ? "Trying…" : "Try again") {
                isRetrying = true
                Task {
                    await catalog.retry()
                    isRetrying = false
                }
            }
            .font(.app(13, .semibold))
            .foregroundStyle(Theme.accentText)
            .disabled(isRetrying)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    /// The credit that opencard-db's license (CC BY 4.0) asks for.
    private var creditLine: some View {
        Link(destination: IssuerCatalogSource.repositoryURL) {
            Text("Bank list from opencard-db (CC BY 4.0)")
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
                .underline()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button("My bank is not listed") {
                // Adds one more card to the count. The bank's name is typed on its card form.
                store.addNotListedCard()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .buttonStyle(.textLink)

            Button(continueTitle) {
                switch mode {
                case .firstPick: store.continueFromPickCards()
                case .addMore: store.continueFromAddCards()
                }
            }
            .buttonStyle(.primary)
            .disabled(pickedCount == 0)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Theme.border.frame(height: 1)
        }
    }

    /// Cards picked on this screen. When adding more cards this counts only the new ones, because
    /// those are the only ones that get a form.
    private var pickedCount: Int {
        switch mode {
        case .firstPick: return store.selectedCount
        case .addMore: return store.newPickCount
        }
    }

    private var continueTitle: String {
        let noun = mode == .addMore ? "new card" : "card"
        switch pickedCount {
        case 0: return "Select a bank to continue"
        case 1: return "Continue with 1 \(noun)"
        default: return "Continue with \(pickedCount) \(noun)s"
        }
    }
}

#Preview("Pick cards – light") {
    NavigationStack {
        PickCardsView()
    }
    .environmentObject(previewStore())
    .environmentObject(IssuerCatalogStore.builtIn())
    .preferredColorScheme(.light)
}

#Preview("Pick cards – dark") {
    NavigationStack {
        PickCardsView()
    }
    .environmentObject(previewStore())
    .environmentObject(IssuerCatalogStore.builtIn())
    .preferredColorScheme(.dark)
}

#Preview("Pick cards – adding more") {
    NavigationStack {
        PickCardsView(mode: .addMore)
    }
    .environmentObject(addingMoreStore())
    .environmentObject(IssuerCatalogStore.builtIn())
    .preferredColorScheme(.light)
}

/// Three cards already added (two Chase, one American Express), with the pick screen reopened from the
/// review screen.
@MainActor
private func addingMoreStore() -> OnboardingStore {
    let store = previewStore()
    store.continueFromPickCards()
    store.startAddingCards()
    return store
}

/// A store with Chase (two cards) and American Express picked.
@MainActor
private func previewStore() -> OnboardingStore {
    let store = OnboardingStore()
    store.toggleSelection(of: BuiltInIssuers.all[0])
    store.increaseCount(of: BuiltInIssuers.all[0])
    store.toggleSelection(of: BuiltInIssuers.all[1])
    return store
}
