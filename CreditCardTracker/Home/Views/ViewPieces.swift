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

/// A white row: tappable content on top that opens the card to edit, and a "Pay Chase ↗" link underneath
/// when the card's lender has a page. The link is a separate button, so it never sits inside the edit button.
struct PayableRow<Content: View>: View {
    let payURL: URL?
    let payTitle: String
    let name: String
    let onEdit: () -> Void
    let onPay: (URL) -> Void
    let content: Content

    init(
        payURL: URL?,
        payTitle: String,
        name: String,
        onEdit: @escaping () -> Void,
        onPay: @escaping (URL) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.payURL = payURL
        self.payTitle = payTitle
        self.name = name
        self.onEdit = onEdit
        self.onPay = onPay
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                content
                    .accessibilityElement(children: .combine)
                    .padding(.top, 14)
                    .padding(.horizontal, 14)
                    .padding(.bottom, payURL == nil ? 14 : 2)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint("Edit this card")

            if let url = payURL {
                Button { onPay(url) } label: {
                    HStack(spacing: 4) {
                        Text(payTitle)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 40, alignment: .leading)
                    .padding(.leading, 14 + 40 + 14)
                    .padding(.trailing, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
                .accessibilityLabel("\(payTitle), \(name)")
                .accessibilityHint("Opens the lender's website or app")
            }
        }
        .dashboardCardStyle()
    }
}
