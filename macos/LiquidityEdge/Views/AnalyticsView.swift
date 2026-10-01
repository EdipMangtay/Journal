import SwiftUI
import Charts

enum AnalyticsMode { case analytics, setups, statistics }
struct AnalyticsView: View {
    @Environment(JournalStore.self) private var store
    var mode: AnalyticsMode
    @State private var filter = TradeFilter()
    @State private var dimension = AnalysisDimension.setup
    @State private var metric = GroupMetric.averageR
    var body: some View {
        let data = filter.apply(store.trades, calendar: store.preferences.calendar), p = AnalyticsEngine.performance(data)
        let groups = AnalyticsEngine.groups(data, by: dimension, calendar: store.preferences.calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Research desk", title: mode == .setups ? "Find the combinations that matter." : mode == .statistics ? "Your performance, precisely." : "Evidence over intuition.", subtitle: "Measure confirmations against your own execution history.")
                FilterBar(allTrades: store.trades, calendar: store.preferences.calendar, filter: $filter)
                if data.isEmpty { EmptyJournal(title: "No observations yet.", subtitle: "Add trades or adjust filters to begin your analysis.") }
                else {
                    if mode == .statistics { MetricsGrid(performance: p, currency: store.preferences.currency) }
                    if mode != .statistics {
                        HStack(spacing: 14) { MetricCard(title: "Sample", value: "n = \(p.count)"); MetricCard(title: "Win rate", value: Format.percent(p.winRate)); MetricCard(title: "Expectancy", value: Format.r(p.averageR)); MetricCard(title: "Compliance", value: Format.percent(p.compliance)) }
                    }
                    Panel(title: "PERFORMANCE BREAKDOWN") {
                        HStack { Picker(L10n.text("Group by"), selection: $dimension) { ForEach(AnalysisDimension.allCases) { Text(L10n.text($0.rawValue)).tag($0) } }.frame(width: 260); Spacer(); Picker(L10n.text("Metric"), selection: $metric) { ForEach(GroupMetric.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) } }.frame(width: 250) }
                        GroupBarChart(groups: groups, metric: metric)
                        GroupMetricsTable(groups: groups, currency: store.preferences.currency)
                    }
                    if mode != .statistics {
                        Text(L10n.text("CONFIRMATION CONTRIBUTION")).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.5)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(AnalyticsEngine.comparisons(data)) { comparison in
                                Panel(title: comparison.title.uppercased()) {
                                    comparisonRow(comparison.left)
                                    Divider()
                                    comparisonRow(comparison.right)
                                    Text(L10n.text("Descriptive comparison; cohorts can differ in setup and execution.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                        edgeMatrix(data)
                    }
                    compliance(data)
                    Panel(title: "SESSION PERFORMANCE") { GroupMetricsTable(groups: AnalyticsEngine.groups(data, by: .session, calendar: store.preferences.calendar), currency: store.preferences.currency) }
                    Panel(title: "ENTRY TIME HEATMAP") { PerformanceHeatmap(trades: data, calendar: store.preferences.calendar) }
                    Panel(title: "METRIC DEFINITIONS") {
                        Text(L10n.text("All PnL metrics use gross PnL minus fees. Win/loss rates include breakeven trades in the denominator. Expectancy is net PnL ÷ trades; expectancy in R and average R both equal total recorded R ÷ trades with R. Average winning R uses winners only. Profit factor is gross net winners ÷ absolute net losers; ∞ means wins with no losses, and — means undefined. Drawdown starts from zero cumulative PnL. Percentage equity uses the configured starting account size, without deposits or withdrawals. Streaks reset on breakeven. Session labels are recorded manually; time buckets use the configured trading time zone. Multi-label groups can overlap.")).font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)
                    }
                }
            }.pagePadding()
        }
    }
    private func comparisonRow(_ group: MetricGroup) -> some View {
        HStack { VStack(alignment: .leading, spacing: 6) { Text(group.name).font(.system(size: 12, weight: .medium)); Text(L10n.text("n = \(group.performance.count) · \(Format.percent(group.performance.winRate)) WR")).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Text(Format.r(group.performance.averageR)).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(Palette.outcome(group.performance.averageR ?? 0)) }
    }
    private func edgeMatrix(_ data: [TradeRecord]) -> some View {
        Panel(title: "EDGE MATRIX", subtitle: "CONFIRMED MODEL COMBINATIONS") {
            let edges = AnalyticsEngine.edgeMatrix(data)
            if edges.isEmpty { Text(L10n.text("Record valid model confirmations to reveal combinations.")).foregroundStyle(Palette.muted) }
            ForEach(edges) { edge in
                HStack { VStack(alignment: .leading, spacing: 6) { Text(edge.name).font(.system(size: 13, weight: .medium)); Badge(text: edge.sampleLabel, color: edge.performance.count < 30 ? Palette.amber : Palette.mint) }; Spacer(); VStack(alignment: .trailing, spacing: 6) { Text(L10n.text("\(Format.percent(edge.performance.winRate)) WR · \(Format.r(edge.performance.averageR)) expectancy")); Text(L10n.text("Avg winning R \(Format.r(edge.performance.averageWinningR)) · n = \(edge.performance.count)")).foregroundStyle(Palette.muted) }.font(.caption.monospaced()) }.padding(.vertical, 7)
            }
            Text(L10n.text("Combinations include trades with additional confirmations. “Only” excludes the other four tracked models. n < 30: low sample; 30+: reasonable sample; 50+: more evidence. Sample count alone does not establish statistical confidence or a durable edge.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private func compliance(_ data: [TradeRecord]) -> some View {
        let months = AnalyticsEngine.monthlyProcess(data, calendar: store.preferences.calendar)
        let correlation = AnalyticsEngine.correlation(months.compactMap { m in m.performance.averageR.map { (m.performance.compliance, $0) } })
        return Panel(title: "DISCIPLINE OVER TIME", subtitle: "MONTHLY RULE COMPLIANCE") {
            Chart(months) { month in
                LineMark(x: .value("Month", month.date), y: .value("Compliance %", month.performance.compliance)).foregroundStyle(Palette.mint)
                PointMark(x: .value("Month", month.date), y: .value("Compliance %", month.performance.compliance)).foregroundStyle(Palette.mint)
            }.chartYScale(domain: 0...100).frame(height: 170)
            ForEach(months) { month in HStack { Text(Format.month(month.date, calendar: store.preferences.calendar)); Spacer(); Text(Format.percent(month.performance.compliance)); Text(Format.r(month.performance.averageR)).frame(width: 90, alignment: .trailing) }.font(.caption) }
            Text(L10n.text(correlation.map { "Monthly compliance ↔ expectancy Pearson r = \(Format.number($0)). Association is not causation; \(months.count) monthly observations." } ?? "Correlation needs at least three months with recorded R and variation in both metrics.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
}
struct GroupMetricsTable: View {
    var groups: [MetricGroup]
    var currency: String
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow { ForEach(["COHORT", "N", "WR", "AVG R", "NET PNL", "EXPECTANCY", "PF"], id: \.self) { Text(L10n.text($0)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) } }
            ForEach(groups) { group in
                let p = group.performance
                GridRow { Text(group.name).frame(maxWidth: .infinity, alignment: .leading); Text(p.count.description); Text(Format.percent(p.winRate)); Text(Format.r(p.averageR)).foregroundStyle(Palette.outcome(p.averageR ?? 0)); Text(Format.money(p.netPnL, currency: currency)); Text(Format.money(p.expectancy, currency: currency)); Text(Format.factor(p)) }.font(.system(size: 11)).monospacedDigit()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct MistakesView: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        let mistakes = AnalyticsEngine.mistakes(store.trades)
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeader(eyebrow: "Process audit", title: "The cost of breaking your rules.", subtitle: "Profitable mistakes are still mistakes. Learn from the process.")
            if mistakes.isEmpty { EmptyJournal(title: "No rule violations recorded.", subtitle: "Honest process reviews are the foundation of a useful journal.") }
            ForEach(mistakes) { mistake in
                Panel {
                    HStack { VStack(alignment: .leading, spacing: 9) { Text(mistake.name).font(.title3.weight(.medium)); Text(L10n.text("\(mistake.performance.count) trades · \(Format.percent(mistake.performance.winRate)) win rate")).foregroundStyle(Palette.muted).font(.caption) }; Spacer(); Text(Format.r(mistake.performance.totalR)).font(.title2.monospaced()).foregroundStyle(Palette.amber); Text(Format.money(mistake.performance.netPnL, currency: store.preferences.currency)).font(.title3).foregroundStyle(Palette.muted) }
                    if mistake.performance.netPnL > 0 { Label(L10n.text("Positive outcome, poor process"), systemImage: "exclamationmark.triangle").foregroundStyle(Palette.amber).font(.caption) }
                }
            }
            if !mistakes.isEmpty { Text(L10n.text("A trade can break multiple rules; counts and PnL overlap between mistakes.")).font(.caption).foregroundStyle(Palette.muted) }
        }.pagePadding() }
    }
}
