import SwiftUI

/// A card the user added with "My card is not listed": a picked row with a text field for the name.
struct CustomCardRow: View {
    let card: CatalogCard
    @Binding var name: String
    var focus: FocusState<String?>.Binding
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CardBadge(card: card)

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    "",
                    text: $name,
                    prompt: Text("Card name").foregroundStyle(Theme.textSecondary)
                )
                .font(.app(16, .semibold))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused(focus, equals: card.id)
                .onSubmit { focus.wrappedValue = nil }
                .accessibilityLabel("Card name")

                Text("Custom card")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            // Unticking a custom card removes it, since it is not in the catalog to find again.
            Button(action: onRemove) {
                Checkbox(isOn: true)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -10)
            .accessibilityLabel("Remove custom card")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Theme.accentTint,
            in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = card.id }
    }
}

private struct CustomCardRowPreview: View {
    @State private var name = ""
    @FocusState private var focus: String?
    private let id = CatalogCard.custom(name: "").id

    var body: some View {
        CustomCardRow(card: CatalogCard.custom(id: id, name: name), name: $name, focus: $focus) {}
            .padding(24)
            .background(Theme.background)
    }
}

#Preview("Custom row") {
    CustomCardRowPreview()
}
