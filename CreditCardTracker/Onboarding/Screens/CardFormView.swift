import SwiftUI

/// Where the form was opened from.
enum CardFormMode {
    /// Right after picking cards: "Card 1 of 2", then on to the next card.
    case onboarding
    /// From "Edit" or "Add details" on the review screen: saving goes back to the review screen.
    case edit
}

/// "Card 1 of 2": optional balance, minimum payment, due date and APR for one picked card.
struct CardFormView: View {
    let cardID: UUID
    var mode: CardFormMode = .onboarding

    @EnvironmentObject private var store: OnboardingStore

    var body: some View {
        if let card = store.card(withID: cardID) {
            CardFormContent(
                card: card,
                mode: mode,
                position: store.position(of: cardID) ?? 1,
                total: max(store.cards.count, 1)
            )
        } else {
            // The card was just removed and the screen is on its way out.
            Theme.background.ignoresSafeArea()
        }
    }
}

private struct CardFormContent: View {
    let card: TrackedCard
    let mode: CardFormMode
    let position: Int
    let total: Int

    @EnvironmentObject private var store: OnboardingStore
    @Environment(\.dismiss) private var dismiss

    @State private var balanceText: String
    @State private var minimumText: String
    @State private var dueDigits: String
    @State private var aprText: String
    @State private var showRemoveConfirmation = false
    @State private var showDatePicker = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case name, balance, minimum, due, apr
    }

    init(card: TrackedCard, mode: CardFormMode, position: Int, total: Int) {
        self.card = card
        self.mode = mode
        self.position = position
        self.total = total
        _balanceText = State(initialValue: FormInput.text(for: card.details.balance))
        _minimumText = State(initialValue: FormInput.text(for: card.details.minimumPayment))
        _dueDigits = State(initialValue: card.details.dueDate?.digits ?? "")
        _aprText = State(initialValue: FormInput.text(for: card.details.apr))
    }

    // MARK: Validation

    private var balanceIsValid: Bool { FormInput.isValidOptionalAmount(balanceText) }
    private var minimumIsValid: Bool { FormInput.isValidOptionalAmount(minimumText) }
    private var aprIsValid: Bool { FormInput.isValidOptionalAmount(aprText) }
    private var dueDateIsValid: Bool { dueDigits.isEmpty || DueDate(digits: dueDigits) != nil }

    private var canSave: Bool {
        balanceIsValid && minimumIsValid && aprIsValid && dueDateIsValid
    }

    private var isLastCard: Bool { position >= total }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    cardTitle
                        .padding(.top, 28)
                    fields
                        .padding(.top, 24)
                    HintBox(text: "Find these on your latest statement, or in your card issuer's app.")
                        .padding(.top, 20)

                    // With room to spare this pushes the buttons to the bottom of the screen. When there
                    // is no room (keyboard open, small screen), the buttons scroll with the rest of the form.
                    Spacer(minLength: 24)

                    actions
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DueDatePickerSheet(digits: $dueDigits)
        }
        .confirmationDialog(
            "Remove \(card.catalogCard.displayName)?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove card", role: .destructive) {
                store.removeCard(card.id)
            }
            Button("Keep card", role: .cancel) {}
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        switch mode {
        case .onboarding:
            HStack(spacing: 16) {
                BackButton()
                StepProgressBar(progress: Double(position) / Double(total))
                Text("Card \(position) of \(total)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 8)
        case .edit:
            HStack {
                BackButton()
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var cardTitle: some View {
        if card.catalogCard.isCustom {
            notListedTitle
        } else {
            listedTitle
        }
    }

    /// A card from the catalog: badge, name and issuer.
    private var listedTitle: some View {
        HStack(spacing: 14) {
            CardBadge(card: card.catalogCard, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.catalogCard.name)
                    .font(.app(22, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.catalogCard.issuer)
                    .font(.app(14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// A card added with "My card is not listed": gray card icon and a field for the name.
    /// Left empty, the card is called "Other card".
    private var notListedTitle: some View {
        HStack(spacing: 14) {
            CardBadge(card: card.catalogCard, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Card name")
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 8) {
                    TextField(
                        "",
                        text: nameBinding,
                        prompt: Text(CatalogCard.defaultCustomName).foregroundStyle(Theme.textSecondary)
                    )
                    .font(.app(22, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = nil }
                    .accessibilityLabel("Card name")

                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                }

                Text(card.catalogCard.issuer)
                    .font(.app(14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = .name }
    }

    /// The name is saved as it is typed, so it is kept even if the user goes back.
    private var nameBinding: Binding<String> {
        Binding(
            get: { card.catalogCard.name },
            set: { store.setCustomName($0, for: card.id) }
        )
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            FormFieldContainer(title: "Balance owed", errorMessage: balanceIsValid ? nil : "Enter a number, like 2480.15.") {
                numberField($balanceText, label: "Balance owed", placeholder: "0.00", prefix: "$", field: .balance, isValid: balanceIsValid)
            }

            HStack(alignment: .top, spacing: 12) {
                FormFieldContainer(title: "Minimum payment", errorMessage: minimumIsValid ? nil : "Enter a number.") {
                    numberField($minimumText, label: "Minimum payment", placeholder: "0.00", prefix: "$", field: .minimum, isValid: minimumIsValid)
                }
                FormFieldContainer(title: "Due date", errorMessage: showDueDateError ? "Use MM / DD." : nil) {
                    dueDateField
                }
            }

            FormFieldContainer(title: "Interest rate (APR)", tag: "Optional", errorMessage: aprIsValid ? nil : "Enter a number, like 24.99.") {
                numberField($aprText, label: "Interest rate (APR)", placeholder: "e.g. 24.99", suffix: "%", field: .apr, isValid: aprIsValid)
            }
        }
    }

    private func numberField(
        _ text: Binding<String>,
        label: String,
        placeholder: String,
        prefix: String? = nil,
        suffix: String? = nil,
        field: Field,
        isValid: Bool
    ) -> some View {
        HStack(spacing: 8) {
            if let prefix {
                Text(prefix)
                    .font(.app(16))
                    .foregroundStyle(Theme.textSecondary)
            }

            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.textSecondary))
                .font(.app(16))
                .foregroundStyle(Theme.textPrimary)
                .keyboardType(.decimalPad)
                .focused($focus, equals: field)
                .accessibilityLabel(label)

            if let suffix {
                Text(suffix)
                    .font(.app(16))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .inputBox(isFocused: focus == field, hasError: !isValid)
        .contentShape(Rectangle())
        .onTapGesture { focus = field }
    }

    /// Only complain about the date once the user has left the field, so it does not flash while typing.
    private var showDueDateError: Bool {
        focus != .due && !dueDateIsValid
    }

    private var dueDateField: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: Binding(
                    get: { FormInput.dueDateDisplay(forDigits: dueDigits) },
                    set: { dueDigits = FormInput.dueDateDigits(fromTyped: $0) }
                ),
                prompt: Text("MM / DD").foregroundStyle(Theme.textSecondary)
            )
            .font(.app(16))
            .foregroundStyle(Theme.textPrimary)
            .keyboardType(.numberPad)
            .focused($focus, equals: .due)
            .accessibilityLabel("Due date, month and day")

            // Opens a calendar to pick the date instead of typing it.
            Button {
                focus = nil
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 15))
                    .foregroundStyle(showDatePicker ? Theme.accent : Theme.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pick due date from calendar")
        }
        .inputBox(isFocused: focus == .due, hasError: showDueDateError)
        .contentShape(Rectangle())
        .onTapGesture { focus = .due }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(primaryTitle) {
                saveAndContinue()
            }
            .buttonStyle(.primary)
            .disabled(!canSave)

            if mode == .onboarding {
                Button("Skip details for now") {
                    focus = nil
                    store.advance(from: card.id)
                }
                .buttonStyle(.secondary)
            }

            Button("Remove this card") {
                focus = nil
                showRemoveConfirmation = true
            }
            .buttonStyle(.customTextLink(size: 15, weight: .medium, color: Theme.danger))
            .padding(.top, 4)
        }
    }

    // MARK: Actions

    private var primaryTitle: String {
        switch mode {
        case .onboarding: return isLastCard ? "Review cards" : "Next card"
        case .edit: return "Save"
        }
    }

    private func saveAndContinue() {
        focus = nil
        let details = CardDetails(
            balance: FormInput.decimal(from: balanceText),
            minimumPayment: FormInput.decimal(from: minimumText),
            dueDate: DueDate(digits: dueDigits),
            apr: FormInput.decimal(from: aprText)
        )
        store.saveDetails(details, for: card.id)
        switch mode {
        case .onboarding: store.advance(from: card.id)
        case .edit: dismiss()
        }
    }
}

#Preview("Card form – light") {
    let store = previewStore()
    NavigationStack {
        CardFormView(cardID: store.cards[0].id)
    }
    .environmentObject(store)
    .preferredColorScheme(.light)
}

#Preview("Card form – dark") {
    let store = previewStore()
    NavigationStack {
        CardFormView(cardID: store.cards[0].id)
    }
    .environmentObject(store)
    .preferredColorScheme(.dark)
}

#Preview("Card form – edit") {
    let store = previewStore()
    NavigationStack {
        CardFormView(cardID: store.cards[0].id, mode: .edit)
    }
    .environmentObject(store)
}

/// A store with the first two cards picked and the first form open, like the design ("Card 1 of 2").
@MainActor
private func previewStore() -> OnboardingStore {
    let store = OnboardingStore()
    store.toggleSelection(of: CardCatalog.all[0])
    store.toggleSelection(of: CardCatalog.all[1])
    store.continueFromPickCards()
    return store
}
