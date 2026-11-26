import SwiftUI

/// The ways to look at the cards on the Views page. The chips at the top switch between them.
enum ViewMode: String, CaseIterable, Identifiable {
    case calendar
    case tiles
    case byBank
    case byWeek
    case chart
    case interest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .tiles: return "Tiles"
        case .byBank: return "By bank"
        case .byWeek: return "By week"
        case .chart: return "Chart"
        case .interest: return "Interest"
        }
    }
}

/// The Views page: a back button, a row of chips, and the chosen view underneath. Opened by "Views" on the
/// home screen. It reads the same cards as the home screen, so a change made anywhere shows up in both.
struct ViewsPage: View {
    @EnvironmentObject private var store: OnboardingStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The view the user picked last time, kept on the phone.
    @AppStorage("viewsMode") private var modeName = ViewMode.calendar.rawValue
    /// Shared with the home screen's sort button.
    @AppStorage("dashboardSort") private var sortName = CardSort.dueDate.rawValue
    /// The card whose sheet is open (tap a card with details), and the card whose form is open ("Add details").
    @State private var opened: EditTarget?
    @State private var editing: EditTarget?

    private var mode: ViewMode {
        ViewMode(rawValue: modeName) ?? .calendar
    }

    private var sort: CardSort {
        CardSort(rawValue: sortName) ?? .dueDate
    }

    var body: some View {
        let data = DashboardData(cards: store.cards, sortedBy: sort, paid: store.paidDueDates, settled: store.settledDueDates)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .padding(.horizontal, Theme.Metrics.screenPadding)

                chips

                content(data)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .cardSheets(opened: $opened, editing: $editing)
    }

    // MARK: Actions

    /// A card with details opens its sheet. A card still missing details goes straight to the form to add them.
    private func open(_ id: UUID, in data: DashboardData) {
        if data.cards.contains(where: { $0.id == id }) {
            opened = EditTarget(id: id)
        } else {
            editing = EditTarget(id: id)
        }
    }

    // MARK: Pieces

    /// "‹ Your cards" and the page title.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Your cards")
                        .font(.app(16, .medium))
                }
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to your cards")

            Text("Views")
                .font(.app(28, .bold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The row of chips. It scrolls sideways when there are more than fit, and keeps the chosen chip in view.
    private var chips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ViewMode.allCases) { option in
                        chip(option)
                            .id(option.rawValue)
                    }
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
            }
            .onAppear {
                proxy.scrollTo(modeName, anchor: .center)
            }
            .onChange(of: modeName) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func chip(_ option: ViewMode) -> some View {
        let isChosen = option == mode
        return Button {
            modeName = option.rawValue
        } label: {
            Text(option.title)
                .font(.app(14, isChosen ? .semibold : .medium))
                .foregroundStyle(isChosen ? Color.white : Theme.textSecondaryOnTint)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isChosen ? Theme.accent : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isChosen ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    @ViewBuilder
    private func content(_ data: DashboardData) -> some View {
        if data.cards.isEmpty && data.incomplete.isEmpty {
            Text("No cards yet. Go back and tap + to add one.")
                .font(.app(15))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        } else {
            switch mode {
            case .calendar:
                CalendarModeView(
                    data: data,
                    onEdit: { open($0, in: data) },
                    onPay: { openURL($0) }
                )
            case .tiles:
                TilesModeView(
                    data: data,
                    sortName: $sortName,
                    onEdit: { open($0, in: data) },
                    onPay: { openURL($0) }
                )
            case .byBank:
                ByBankModeView(
                    data: data,
                    onEdit: { open($0, in: data) },
                    onPay: { openURL($0) }
                )
            case .byWeek:
                ByWeekModeView(
                    data: data,
                    onEdit: { open($0, in: data) },
                    onPay: { openURL($0) }
                )
            case .chart:
                ChartModeView(data: data)
            case .interest:
                InterestModeView(
                    data: data,
                    onEdit: { editing = EditTarget(id: $0) }
                )
            }
        }
    }
}

#Preview("Views – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}

#Preview("Views – dark") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.dark)
}

/// Six cards: five with details and due days close to today, one without.
@MainActor
func viewsPreviewStore() -> OnboardingStore {
    let store = OnboardingStore()
    for card in CardCatalog.all.prefix(6) {
        store.toggleSelection(of: card)
    }
    store.continueFromPickCards()

    let calendar = Calendar.current
    func due(in days: Int) -> DueDate? {
        let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return DueDate(date: date)
    }

    let samples: [(balance: Decimal, minimum: Decimal, days: Int, apr: Decimal?)] = [
        (2480.15, 75, 2, 24.99),
        (1120.40, 35, 7, 29.74),
        (860, 35, 10, 23.99),
        (640, 25, 13, 21.49),
        (1890.22, 60, 18, nil),
    ]
    for (card, sample) in zip(store.cards, samples) {
        store.saveDetails(
            CardDetails(
                balance: sample.balance,
                minimumPayment: sample.minimum,
                dueDate: due(in: sample.days),
                apr: sample.apr
            ),
            for: card.id
        )
    }
    return store
}
