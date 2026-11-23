import SwiftUI

/// "Pick your cards": search the catalog and tick every card the user wants to track.
struct PickCardsView: View {
    @EnvironmentObject private var store: OnboardingStore
    @State private var query = ""

    private var results: [CatalogCard] {
        CardCatalog.cards(matching: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                BackButton()
                    .padding(.top, 8)

                Text("Pick your cards")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 12)

                Text("Choose every credit card you want to keep track of. You can add more later.")
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
                prompt: Text("Search by card or bank").foregroundStyle(Theme.textSecondary)
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
                ForEach(results) { card in
                    CardPickRow(card: card, isSelected: store.isSelected(card)) {
                        store.toggleSelection(of: card)
                    }
                }

                if results.isEmpty {
                    Text("No cards match “\(query)”.")
                        .font(.app(15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 4)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button("My card is not listed") {
                // Adds one more card to the count. Its name is typed on its card form.
                store.addNotListedCard()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .buttonStyle(.textLink)

            Button(continueTitle) {
                store.continueFromPickCards()
            }
            .buttonStyle(.primary)
            .disabled(store.selectedCount == 0)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Theme.border.frame(height: 1)
        }
    }

    private var continueTitle: String {
        switch store.selectedCount {
        case 0: return "Select a card to continue"
        case 1: return "Continue with 1 card"
        default: return "Continue with \(store.selectedCount) cards"
        }
    }
}

#Preview("Pick cards – light") {
    NavigationStack {
        PickCardsView()
    }
    .environmentObject(previewStore())
    .preferredColorScheme(.light)
}

#Preview("Pick cards – dark") {
    NavigationStack {
        PickCardsView()
    }
    .environmentObject(previewStore())
    .preferredColorScheme(.dark)
}

/// A store with the first two cards already picked, like the design.
@MainActor
private func previewStore() -> OnboardingStore {
    let store = OnboardingStore()
    store.toggleSelection(of: CardCatalog.all[0])
    store.toggleSelection(of: CardCatalog.all[1])
    return store
}
