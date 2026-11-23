import SwiftUI

/// "Review cards": every picked card with its details, then "Confirm and finish".
struct ReviewView: View {
    @EnvironmentObject private var store: OnboardingStore

    private var hasIncompleteCards: Bool {
        store.cards.contains { !$0.detailsComplete }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackButton()
                    .padding(.top, 8)

                Text("Review cards")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 12)

                Text("Check that everything looks right. You can change any of this later.")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                totalBlock
                    .padding(.top, 24)

                VStack(spacing: 12) {
                    ForEach(store.cards) { card in
                        ReviewCardRow(card: card) {
                            store.path.append(.editCard(card.id))
                        }
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Pieces

    private var totalBlock: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total balance")
                    .font(.app(13, .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(store.cards.totalBalance.formatted(.currency(code: "USD")))
                    .font(.app(34, .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 8)

            Text(store.cards.count == 1 ? "1 card" : "\(store.cards.count) cards")
                .font(.app(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if hasIncompleteCards {
                Text("Cards without details won't count toward your totals until you add them.")
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                Button("Confirm and finish") {
                    store.finishOnboarding()
                }
                .buttonStyle(.primary)

                // Back to "Pick your cards" with the current cards ticked, to add more.
                Button {
                    store.startAddingCards()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add another card")
                    }
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

#Preview("Review – light") {
    let store = previewStore()
    NavigationStack {
        ReviewView()
    }
    .environmentObject(store)
    .preferredColorScheme(.light)
}

#Preview("Review – dark") {
    let store = previewStore()
    NavigationStack {
        ReviewView()
    }
    .environmentObject(store)
    .preferredColorScheme(.dark)
}

/// Two cards like the design: Chase Freedom Unlimited filled in, Chase Sapphire Preferred without details.
@MainActor
private func previewStore() -> OnboardingStore {
    let store = OnboardingStore()
    store.toggleSelection(of: CardCatalog.all[0])
    store.toggleSelection(of: CardCatalog.all[1])
    store.continueFromPickCards()
    store.saveDetails(
        CardDetails(
            balance: 2480.15,
            minimumPayment: 45,
            dueDate: DueDate(month: 12, day: 14),
            apr: 24.99
        ),
        for: store.cards[0].id
    )
    return store
}
