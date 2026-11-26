import SwiftUI

/// "Due Nov 28 · in 2 days" with the second part colored by how soon, or "Paid · next due Dec 28".
/// With `showsWeekday` the date reads "Sat, Nov 28".
struct DueLine: View {
    let item: DashboardCard
    var showsWeekday = false

    private var dateText: String {
        guard showsWeekday else { return item.dueOnText }
        return item.nextDueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var whenColor: Color {
        switch item.urgency {
        case .urgent: return Theme.danger
        case .soon: return Theme.accentText
        case .calm: return Theme.textSecondary
        }
    }

    var body: some View {
        if item.isPaid {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accentText)
                    .accessibilityHidden(true)
                Text("Paid · next due \(item.dueOnText)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            HStack(spacing: 0) {
                Text(showsWeekday ? "\(dateText) · " : "Due \(dateText) · ")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
                Text(item.whenText)
                    .font(.app(13, item.urgency == .calm ? .regular : .semibold))
                    .foregroundStyle(whenColor)
            }
        }
    }
}

/// "Mark paid" on a card whose coming payment is not marked yet, "Mark unpaid" on one that is.
struct PaidToggleButton: View {
    let isPaid: Bool
    let name: String
    let action: () -> Void

    private var title: String { isPaid ? "Mark unpaid" : "Mark paid" }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isPaid ? "arrow.uturn.backward" : "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .lineLimit(1)
            }
            .fixedSize()
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(TextLinkButtonStyle(size: 14))
        .accessibilityLabel("\(title), \(name)")
        .accessibilityHint(
            isPaid
                ? "Puts this payment back on your list as not paid"
                : "Moves this card on to next month's due date"
        )
    }
}

/// The line under a card: "Pay Chase ↗" on the left when the lender has a page, and "Mark paid" or
/// "Mark unpaid" on the right. Both are separate buttons, so neither sits inside the edit button above.
struct CardActionsRow: View {
    let payURL: URL?
    let payTitle: String
    let name: String
    let isPaid: Bool
    let onPay: (URL) -> Void
    /// Nil leaves the Mark paid button out.
    let onTogglePaid: (() -> Void)?

    /// Space to the left of the text: the row's padding, the badge and the gap after it.
    static let textInset: CGFloat = 14 + 40 + 14

    var body: some View {
        HStack(spacing: 12) {
            if let url = payURL {
                Button { onPay(url) } label: {
                    HStack(spacing: 4) {
                        Text(payTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 40, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
                .accessibilityLabel("\(payTitle), \(name)")
                .accessibilityHint("Opens the lender's website or app")
            }

            Spacer(minLength: 8)

            if let onTogglePaid {
                PaidToggleButton(isPaid: isPaid, name: name, action: onTogglePaid)
            }
        }
        .padding(.leading, Self.textInset)
        .padding(.trailing, 14)
    }
}

/// A white row: tappable content on top that opens the card to edit, and underneath a "Pay Chase ↗" link when
/// the card's lender has a page, with "Mark paid" or "Mark unpaid" beside it. They are separate buttons, so
/// neither sits inside the edit button.
struct PayableRow<Content: View>: View {
    let payURL: URL?
    let payTitle: String
    let name: String
    let isPaid: Bool
    let onEdit: () -> Void
    let onPay: (URL) -> Void
    let onTogglePaid: () -> Void
    let content: Content

    init(
        payURL: URL?,
        payTitle: String,
        name: String,
        isPaid: Bool,
        onEdit: @escaping () -> Void,
        onPay: @escaping (URL) -> Void,
        onTogglePaid: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.payURL = payURL
        self.payTitle = payTitle
        self.name = name
        self.isPaid = isPaid
        self.onEdit = onEdit
        self.onPay = onPay
        self.onTogglePaid = onTogglePaid
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                content
                    .accessibilityElement(children: .combine)
                    .padding(.top, 14)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint("Edit this card")

            CardActionsRow(
                payURL: payURL,
                payTitle: payTitle,
                name: name,
                isPaid: isPaid,
                onPay: onPay,
                onTogglePaid: onTogglePaid
            )
        }
        .dashboardCardStyle()
    }
}
