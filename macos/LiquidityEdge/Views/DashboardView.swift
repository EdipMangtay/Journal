import SwiftUI

struct DashboardView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    var newTrade: () -> Void
    @State private var period = "ALL TIME"
    @State private var curveMode = CurveMode.dollars
    private var trades: [TradeRecord] {
        let c = store.preferences.calendar
        let component: Calendar.Component? = period == "TODAY" ? .day : period == "THIS WEEK" ? .weekOfYear : period == "THIS MONTH" ? .month : nil
        guard let component, let interval = c.dateInterval(of: component, for: Date()) else { return store.trades }
        return store.trades.filter { interval.contains($0.date) }
    }
    var body: some View {
        let data = trades, p = AnalyticsEngine.performance(data), curve = AnalyticsEngine.curve(data)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    PageHeader(eyebrow: "Performance overview", title: "Process is the edge.", subtitle: "Professional Trading Performance Journal")
                    Spacer()
                    SegmentedTabs(options: ["TODAY", "THIS WEEK", "THIS MONTH", "ALL TIME"], selection: $period, title: { $0 }).accessibilityLabel("Dashboard period")
                }
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.shield").font(.system(size: 23, weight: .light)).foregroundStyle(Palette.mint)
                    VStack(alignment: .leading, spacing: 5) { Text("Discipline before dollars.").font(.system(size: 13, weight: .medium)); Text(data.isEmpty ? "Your process is measured independently of your PnL." : "\(data.filter(\.compliant).count) of \(data.count) trades respected your plan. Review the exceptions.").font(.caption).foregroundStyle(Palette.muted) }
                    Spacer(); Badge(text: "\(Format.percent(p.compliance)) COMPLIANCE", color: p.compliance >= 80 ? Palette.mint : Palette.amber)
                }.padding(18).background(Palette.mint.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.mint.opacity(0.13)))
                if data.isEmpty { EmptyJournal(action: newTrade) }
                else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        MetricCard(title: "Net PnL", value: Format.money(p.netPnL, currency: store.preferences.currency), footnote: "After commissions & fees", color: Palette.outcome(p.netPnL))
                        MetricCard(title: "Total R", value: Format.r(p.totalR), footnote: "\(p.rCount) trades with recorded R", color: Palette.outcome(p.totalR))
                        MetricCard(title: "Win rate", value: Format.percent(p.winRate), footnote: "\(p.wins) wins / \(p.count) trades")
                        MetricCard(title: "Expectancy", value: Format.r(p.averageR), footnote: "Expected R per recorded trade", color: Palette.outcome(p.averageR ?? 0))
                    }
                    Panel(title: "EQUITY CURVE", subtitle: "CLOSED TRADES · NET OF FEES") {
                        HStack(alignment: .firstTextBaseline) { Text(curveMode == .r ? Format.r(p.totalR) : curveMode == .percent ? Format.percent(p.netPnL / store.preferences.accountSize * 100) : Format.money(p.netPnL, currency: store.preferences.currency)).font(.system(size: 29, weight: .medium, design: .rounded)).monospacedDigit(); Spacer(); SegmentedTabs(options: [CurveMode.dollars, .r, .percent], selection: $curveMode, title: { $0.rawValue }).accessibilityLabel("Equity curve unit") }
                        EquityChart(points: curve, mode: curveMode, accountSize: store.preferences.accountSize)
                        HStack { Label("Starting balance \(Format.money(store.preferences.accountSize, currency: store.preferences.currency))", systemImage: "circle.dotted"); Spacer(); Text("\(p.count) observations") }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        Panel(title: "EXECUTION QUALITY") {
                            HStack { Text(Format.number(p.executionScore, digits: 0)).font(.system(size: 42, weight: .light, design: .rounded)); Text("/ 100").foregroundStyle(Palette.muted); Spacer(); Image(systemName: "scope").font(.largeTitle).foregroundStyle(Palette.mint.opacity(0.6)) }
                            ProgressView(value: p.executionScore, total: 100).tint(Palette.mint)
                            HStack { Text("A+ setup win rate"); Spacer(); Text(p.aPlusWinRate.map(Format.percent) ?? "—").monospacedDigit() }.font(.caption)
                        }.frame(maxWidth: 340)
                        Panel(title: "PROCESS / OUTCOME") {
                            ForEach([Classification.validWinner, .validLoser, .invalidWinner, .invalidLoser], id: \.self) { type in
                                HStack { Circle().fill(Palette.classification(type)).frame(width: 6, height: 6); Text(type.rawValue).font(.system(size: 10, design: .monospaced)); Spacer(); Text(data.filter { $0.classification == type }.count.description).monospacedDigit() }
                            }
                        }
                    }
                    Panel(title: "WHEN YOUR EDGE SHOWS UP", subtitle: "AVERAGE R") { PerformanceHeatmap(trades: data, calendar: store.preferences.calendar) }
                    HStack(alignment: .top, spacing: 16) {
                        Panel(title: "CUMULATIVE R") { EquityChart(points: curve, mode: .r, height: 160) }
                        Panel(title: "DRAWDOWN") { EquityChart(points: curve, mode: .drawdown, height: 160) }
                    }
                    Panel(title: "ROLLING WIN RATE", subtitle: "LAST 20 TRADES · SHORTER WINDOW UNTIL 20") { EquityChart(points: Array(curve.dropFirst()), mode: .rolling, height: 150) }
                    Panel(title: "RECENT EXECUTIONS", subtitle: "PROCESS > OUTCOME") { TradeRows(trades: Array(data.prefix(6)), openTrade: openTrade) }
                    MetricsGrid(performance: p, currency: store.preferences.currency)
                }
            }.pagePadding()
        }
    }
}
struct MetricsGrid: View {
    var performance: Performance
    var currency: String
    var body: some View {
        let p = performance
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricCard(title: "Profit factor", value: Format.factor(p))
            MetricCard(title: "Expectancy / trade", value: Format.money(p.expectancy, currency: currency))
            MetricCard(title: "Average winner", value: Format.money(p.averageWinner, currency: currency))
            MetricCard(title: "Average loser", value: Format.money(p.averageLoser, currency: currency))
            MetricCard(title: "Average R", value: Format.r(p.averageR))
            MetricCard(title: "Best trade", value: Format.money(p.bestTrade, currency: currency))
            MetricCard(title: "Worst trade", value: Format.money(p.worstTrade, currency: currency))
            MetricCard(title: "Max drawdown", value: Format.money(p.maxDrawdown, currency: currency))
            MetricCard(title: "Current win streak", value: p.currentWinStreak.description)
            MetricCard(title: "Current loss streak", value: p.currentLossStreak.description)
            MetricCard(title: "Rule compliance", value: Format.percent(p.compliance))
            MetricCard(title: "Total trades", value: p.count.description)
            MetricCard(title: "Loss rate", value: Format.percent(p.lossRate))
            MetricCard(title: "Recovery factor", value: p.recoveryFactor.map { Format.number($0) } ?? "—")
            MetricCard(title: "Realized payoff ratio", value: p.payoffRatio.map { Format.number($0) } ?? "—")
            MetricCard(title: "Average duration", value: p.averageDuration.map { Format.number($0 / 60, digits: 0) + " min" } ?? "—")
        }
    }
}
