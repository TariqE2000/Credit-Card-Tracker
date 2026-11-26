import SwiftUI

/// The Calendar view: one month with a dot on every day a card is due, and the cards due on the day
/// you tap. Due dates repeat monthly, so every month shows them.
struct CalendarModeView: View {
    let data: DashboardData
    let onEdit: (UUID) -> Void
    let onPay: (URL) -> Void

    /// Any date inside the month on show.
    @State private var shownMonth = Date()
    /// The day whose cards are listed underneath. Today until the user taps another day.
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var isShowingThisMonth: Bool {
        calendar.isDate(shownMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        if let month = CalendarMonth(cards: data.cards, month: shownMonth) {
            VStack(alignment: .leading, spacing: 20) {
                monthCard(month)
                selectedDay(month)
                summary(month)

                Text(footnote)
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footnote: String {
        var text = "Due dates repeat every month."
        if isShowingThisMonth { text += " Faded dots are dates that already passed this month." }
        if !data.incomplete.isEmpty { text += " Cards without details are not on the calendar." }
        return text
    }

    // MARK: Month

    private func monthCard(_ month: CalendarMonth) -> some View {
        VStack(spacing: 4) {
            HStack {
                arrow("chevron.left", label: "Previous month") { moveMonth(by: -1) }
                Spacer()
                Text(month.title)
                    .font(.app(17, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                arrow("chevron.right", label: "Next month") { moveMonth(by: 1) }
            }

            HStack(spacing: 0) {
                ForEach(Array(CalendarMonth.weekdayLetters().enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.app(12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            .accessibilityHidden(true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }
                ForEach(month.days) { day in
                    dayCell(day)
                }
            }
        }
        .padding(8)
        .dashboardCardStyle()
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private func dayCell(_ day: CalendarMonth.Day) -> some View {
        let isToday = calendar.isDate(day.date, inSameDayAs: Date())
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let isPast = day.date < today

        return Button {
            selectedDate = day.date
        } label: {
            VStack(spacing: 2) {
                Text("\(day.number)")
                    .font(.app(15, isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Theme.accentText : (isPast ? Theme.textSecondary : Theme.textPrimary))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if isToday {
                            Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                        }
                    }

                dots(for: day.cards, faded: isPast)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isSelected ? Theme.accentTint : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Up to three dots under the date, each in the color of the card's bank.
    private func dots(for cards: [DashboardCard], faded: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(cards.prefix(3).enumerated()), id: \.offset) { _, item in
                Circle()
                    .fill(Color(hex: item.card.catalogCard.badgeColorHex))
                    .frame(width: 6, height: 6)
                    .opacity(faded ? 0.4 : 1)
            }
        }
        .frame(height: 6)
    }

    private func accessibilityText(for day: CalendarMonth.Day) -> String {
        let date = day.date.formatted(.dateTime.month(.abbreviated).day())
        guard !day.cards.isEmpty else { return date }
        let names = day.cards.map { $0.card.catalogCard.displayName }.joined(separator: ", ")
        return "\(date), \(names) due"
    }

    private func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: shownMonth) else { return }
        shownMonth = next
        selectedDate = calendar.isDate(next, equalTo: Date(), toGranularity: .month) ? today : nil
    }

    // MARK: Selected day

    @ViewBuilder
    private func selectedDay(_ month: CalendarMonth) -> some View {
        if let selected = selectedDate,
           let day = month.days.first(where: { calendar.isDate($0.date, inSameDayAs: selected) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.app(18, .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text(countText(day.cards.count))
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }

                ForEach(day.cards) { item in
                    CalendarDueRow(
                        item: item,
                        date: day.date,
                        today: today,
                        onEdit: { onEdit(item.id) },
                        onPay: onPay
                    )
                }
            }
        } else {
            Text("Tap a day to see what is due.")
                .font(.app(14))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func countText(_ count: Int) -> String {
        switch count {
        case 0: return "Nothing due"
        case 1: return "1 card due"
        default: return "\(count) cards due"
        }
    }

    // MARK: Summary

    private func summary(_ month: CalendarMonth) -> some View {
        let figures = isShowingThisMonth ? month.due(onOrAfter: today) : month.dueAllMonth
        let cardText = figures.cardCount == 1 ? "1 card" : "\(figures.cardCount) cards"
        return HStack {
            Text(isShowingThisMonth ? "Still ahead this month" : "Due this month")
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(figures.minimums.usd) · \(cardText)")
                .font(.app(14, .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.app(14))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .dashboardCardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// A card due on the day picked in the calendar: badge, name, how far away the day is, balance and minimum.
private struct CalendarDueRow: View {
    let item: DashboardCard
    let date: Date
    let today: Date
    let onEdit: () -> Void
    let onPay: (URL) -> Void

    private var daysAway: Int {
        Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    /// Past days show the "Pay" link only when they are today or later.
    private var payURL: URL? { daysAway >= 0 ? item.payURL : nil }

    private var whenColor: Color {
        guard daysAway >= 0 else { return Theme.textSecondary }
        switch DueUrgency(daysUntilDue: daysAway) {
        case .urgent: return Theme.danger
        case .soon: return Theme.accentText
        case .calm: return Theme.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    CardBadge(card: item.card.catalogCard)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.card.catalogCard.displayName)
                            .font(.app(16, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 0) {
                            Text("Due \(date.formatted(.dateTime.month(.abbreviated).day())) · ")
                                .font(.app(13))
                                .foregroundStyle(Theme.textSecondary)
                            Text(DueWording.text(daysAway: daysAway))
                                .font(.app(13, daysAway >= 0 && daysAway <= DashboardData.dueSoonDays ? .semibold : .regular))
                                .foregroundStyle(whenColor)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.balance.usd)
                            .font(.app(16, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Min \(item.minimumPayment.usd)")
                            .font(.app(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
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
                        Text(item.payTitle)
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
                .accessibilityLabel("\(item.payTitle), \(item.card.catalogCard.displayName)")
                .accessibilityHint("Opens the lender's website or app")
            }
        }
        .dashboardCardStyle()
    }
}

#Preview("Calendar – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
