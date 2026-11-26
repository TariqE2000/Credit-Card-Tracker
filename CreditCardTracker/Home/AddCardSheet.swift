import SwiftUI

/// The sheet behind the "+" button on the home screen: "Pick your cards" with the cards the user already
/// has locked, then a form for each new card. It closes after the last form.
///
/// It uses the same screens as "Add another card" on the review screen. The store's `path` drives the
/// forms, and `OnboardingStore.isAddingFromHome` tells the home screen when to close the sheet.
struct AddCardSheet: View {
    @EnvironmentObject private var store: OnboardingStore

    var body: some View {
        NavigationStack(path: $store.path) {
            PickCardsView(mode: .addMore)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .editCard(let id):
                        CardFormView(cardID: id, mode: .edit)
                    case .cardForm(let id):
                        CardFormView(cardID: id)
                    case .logIn, .pickCards, .addCards, .review:
                        // Not used here. The sheet only ever pushes card forms.
                        PickCardsView(mode: .addMore)
                    }
                }
        }
        // The pick screen reads the card list from here. The home screen is not inside the onboarding flow
        // that normally provides it.
        .environmentObject(store.catalog)
    }
}

#Preview("Add card sheet") {
    let store = OnboardingStore()
    store.toggleSelection(of: CardCatalog.all[0])
    store.continueFromPickCards()
    store.startAddingFromHome()
    return AddCardSheet()
        .environmentObject(store)
}
