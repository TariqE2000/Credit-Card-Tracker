import SwiftUI

/// The calendar that opens from the calendar icon on the Due date field.
///
/// A card's due date repeats every month, so only the month and day are kept. The year in the
/// calendar is just there to make it a real calendar. Picking a day fills the field right away.
struct DueDatePickerSheet: View {
    /// The four digits of the due date, like "1214". Shared with the Due date field.
    @Binding var digits: String

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date
    private let range: ClosedRange<Date>

    init(digits: Binding<String>) {
        _digits = digits

        let calendar = Calendar.current
        let now = Date()
        // Start at the first of this month so a due date earlier this month can still be picked.
        // Four years of dates is enough to reach a Feb 29.
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .year, value: 4, to: start) ?? start
        let bounds = start...end
        range = bounds

        let existing = DueDate(digits: digits.wrappedValue)?
            .nextOccurrence(onOrAfter: start, calendar: calendar)
        if let existing, bounds.contains(existing) {
            _selection = State(initialValue: existing)
        } else {
            _selection = State(initialValue: now)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Due date")
                    .font(.app(20, .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.customTextLink(size: 17, weight: .semibold, color: Theme.accent))
            }

            Text("Pick the day your payment is due. Only the month and day are saved.")
                .font(.app(14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            DatePicker(
                "Due date",
                selection: Binding(
                    get: { selection },
                    set: { newValue in
                        selection = newValue
                        if let due = DueDate(date: newValue) {
                            digits = due.digits
                        }
                    }
                ),
                in: range,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Theme.accent)
            .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.height(580), .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Due date picker") {
    struct Host: View {
        @State var digits = ""
        var body: some View {
            Color.clear.sheet(isPresented: .constant(true)) {
                DueDatePickerSheet(digits: $digits)
            }
        }
    }
    return Host()
}
