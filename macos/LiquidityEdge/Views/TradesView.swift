import SwiftUI

struct TradeRows: View {
    @Environment(JournalStore.self) private var store
    var trades: [TradeRecord]
    var openTrade: (TradeRecord) -> Void
    var body: some View {
        LazyVStack(spacing: 0) {
            HStack { Text(L10n.text("INSTRUMENT / SETUP")); Spacer(); Text(L10n.text("PROCESS")).frame(width: 150); Text(L10n.text("NET PNL")).frame(width: 110, alignment: .trailing); Text(L10n.text("R")).frame(width: 70, alignment: .trailing) }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted).padding(.bottom, 12)
            ForEach(trades) { trade in
                Button { openTrade(trade) } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6).fill(Palette.raised).frame(width: 34, height: 34).overlay(Image(systemName: trade.direction == "Long" ? "arrow.up.right" : "arrow.down.right").foregroundStyle(Palette.muted))
                        VStack(alignment: .leading, spacing: 5) { HStack { Text(trade.instrument).fontWeight(.semibold); Text(L10n.text(trade.direction.uppercased())).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted); Text(Format.date(trade.date, calendar: store.preferences.calendar)).font(.caption).foregroundStyle(Palette.muted) }; Text((trade.setupID == nil ? L10n.text(trade.setupName) : trade.setupName) + " · " + L10n.text(trade.session)).font(.caption).foregroundStyle(Palette.muted) }
                        Spacer(); Badge(text: trade.classification.rawValue, color: Palette.classification(trade.classification)).frame(width: 150)
                        Text(Format.money(trade.netPnL, currency: store.preferences.currency)).foregroundStyle(Palette.outcome(trade.netPnL)).frame(width: 110, alignment: .trailing)
                        Text(Format.r(trade.rMultiple)).foregroundStyle(Palette.outcome(trade.rMultiple ?? 0)).frame(width: 70, alignment: .trailing)
                    }.font(.system(size: 12)).monospacedDigit().padding(.vertical, 13).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider().overlay(Palette.muted.opacity(0.08))
            }
        }
    }
}
struct FilterBar: View {
    var allTrades: [TradeRecord]
    var calendar: Calendar
    @Binding var filter: TradeFilter
    @State private var advanced = false
    @State private var dateEnabled = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField(L10n.text("Search instrument, model, emotion, notes…"), text: $filter.query).textFieldStyle(.plain)
                Button { advanced.toggle() } label: { Label(L10n.text("Filters \(filter.facets.values.filter { !$0.isEmpty }.count)"), systemImage: "line.3.horizontal.decrease") }.buttonStyle(.bordered)
                Button(L10n.text("Reset")) { filter = TradeFilter(); dateEnabled = false }.buttonStyle(.borderless)
            }
            if advanced {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(AnalysisDimension.allCases) { dimension in
                        Picker(L10n.text(dimension.rawValue), selection: Binding(get: { filter.facets[dimension] ?? "" }, set: { filter.facets[dimension] = $0 })) {
                            Text(L10n.text("All")).tag("")
                            ForEach(Array(Set(allTrades.flatMap { dimension.keys($0, calendar: calendar) })).sorted(), id: \.self) { Text(L10n.text($0)).tag($0) }
                        }
                    }
                }
                HStack {
                    Toggle(L10n.text("Date range"), isOn: $dateEnabled).onChange(of: dateEnabled) { _, enabled in filter.from = enabled ? calendar.date(byAdding: .month, value: -1, to: Date()) : nil; filter.to = enabled ? Date() : nil }
                    if dateEnabled { DatePicker(L10n.text("From"), selection: Binding(get: { filter.from ?? Date() }, set: { filter.from = $0 }), displayedComponents: .date); DatePicker(L10n.text("Through"), selection: Binding(get: { filter.to ?? Date() }, set: { filter.to = $0 }), displayedComponents: .date) }
                    Spacer()
                }
            }
        }.padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}
struct TradesView: View {
    @Environment(JournalStore.self) private var store
    var initialQuery: String
    var openTrade: (TradeRecord) -> Void
    var newTrade: () -> Void
    @State private var filter = TradeFilter()
    @State private var sort = "Newest"
    var body: some View {
        let filtered = filter.apply(store.trades, calendar: store.preferences.calendar)
        let sorted = filtered.sorted { a, b in switch sort { case "Oldest": return a.date < b.date; case "Best R": return (a.rMultiple ?? -.infinity) > (b.rMultiple ?? -.infinity); case "Best PnL": return a.netPnL > b.netPnL; default: return a.date > b.date } }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { PageHeader(eyebrow: "Execution log", title: "Every trade tells a story.", subtitle: "\(filtered.count) trades · Search, inspect and refine your process."); Spacer(); Picker(L10n.text("Sort"), selection: $sort) { ForEach(["Newest", "Oldest", "Best R", "Best PnL"], id: \.self) { Text(L10n.text($0)) } }.frame(width: 190) }
                FilterBar(allTrades: store.trades, calendar: store.preferences.calendar, filter: $filter)
                if sorted.isEmpty { EmptyJournal(title: store.trades.isEmpty ? "Your journal is ready." : "No matching trades.", subtitle: store.trades.isEmpty ? "Start with a quick entry. Add context when you review." : "Change your search or reset the filters.", action: newTrade) }
                else { Panel { TradeRows(trades: sorted, openTrade: openTrade) } }
            }.pagePadding()
        }.onAppear { filter.query = initialQuery }.onChange(of: initialQuery) { _, value in filter.query = value }
    }
}
