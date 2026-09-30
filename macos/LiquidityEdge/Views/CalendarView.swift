import SwiftUI

struct CalendarView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    @State private var month = Date()
    @State private var selectedDate: Date?
    @State private var showR = false
    var body: some View {
        let calendar = store.preferences.calendar
        let interval = calendar.dateInterval(of: .month, for: month)!
        let monthTrades = store.trades.filter { interval.contains($0.date) }
        let p = AnalyticsEngine.performance(monthTrades)
        let buckets = Dictionary(grouping: monthTrades) { calendar.startOfDay(for: $0.date) }
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { PageHeader(eyebrow: "Session by session", title: "The rhythm of your trading.", subtitle: "Daily outcomes, with the process one click away."); Spacer(); Toggle("Show R", isOn: $showR).toggleStyle(.switch) }
            HStack { MetricCard(title: "Monthly PnL", value: Format.money(p.netPnL, currency: store.preferences.currency)); MetricCard(title: "Monthly R", value: Format.r(p.totalR)); MetricCard(title: "Win rate", value: Format.percent(p.winRate)); MetricCard(title: "Trades", value: p.count.description) }
            Panel {
                HStack { Button { shift(-1) } label: { Image(systemName: "chevron.left") }; Text(Format.month(month, calendar: calendar)).font(.title3.weight(.medium)); Button { shift(1) } label: { Image(systemName: "chevron.right") }; Spacer(); Button("This month") { month = Date(); selectedDate = nil } }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { Text($0).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) }
                    ForEach(0..<(offset + count), id: \.self) { index in
                        if index < offset { Color.clear.frame(height: 100) }
                        else {
                            let date = calendar.date(byAdding: .day, value: index - offset, to: interval.start)!
                            let dayTrades = buckets[date] ?? [], stats = AnalyticsEngine.performance(dayTrades)
                            let number = showR ? stats.totalR : stats.netPnL
                            Button { selectedDate = date } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack { Text("\(index - offset + 1)").foregroundStyle(Palette.muted); Spacer(); if calendar.isDateInToday(date) { Circle().fill(Palette.mint).frame(width: 5, height: 5) } }
                                    if !dayTrades.isEmpty { Text(showR ? Format.r(number) : Format.money(number, currency: store.preferences.currency)).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Palette.outcome(number)).lineLimit(1).minimumScaleFactor(0.6); Text("\(stats.count) trades").font(.system(size: 9)).foregroundStyle(Palette.muted) }
                                    Spacer(minLength: 0)
                                }.padding(12).frame(height: 100).frame(maxWidth: .infinity, alignment: .leading).background(dayTrades.isEmpty ? Palette.raised.opacity(0.35) : Palette.outcome(number).opacity(0.075), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selectedDate == date ? Palette.mint.opacity(0.7) : Palette.muted.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if let selectedDate {
                Panel(title: Format.date(selectedDate, calendar: calendar).uppercased()) { let selected = buckets[calendar.startOfDay(for: selectedDate)] ?? []; if selected.isEmpty { Text("No trades on this day.").foregroundStyle(Palette.muted) } else { TradeRows(trades: selected, openTrade: openTrade) } }
            }
        }.pagePadding() }
    }
    private func shift(_ value: Int) { month = store.preferences.calendar.date(byAdding: .month, value: value, to: month) ?? month; selectedDate = nil }
}
