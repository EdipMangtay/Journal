import SwiftUI
import Charts

enum CurveMode: String, CaseIterable { case dollars = "$", r = "R", percent = "%", drawdown = "Drawdown", rolling = "Rolling WR" }
struct EquityChart: View {
    var points: [CurvePoint]
    var mode: CurveMode = .dollars
    var accountSize: Double = 50000
    var height: CGFloat = 260
    @State private var selectedDate: Date?
    @State private var revealed = false
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var color: Color { mode == .drawdown ? Palette.red : mode == .rolling ? Palette.blue : Palette.mint }
    private func value(_ p: CurvePoint) -> Double { switch mode { case .dollars: return p.equity; case .r: return p.r; case .percent: return accountSize > 0 ? p.equity / accountSize * 100 : 0; case .drawdown: return p.drawdown; case .rolling: return p.rollingWinRate } }
    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date), y: .value("Performance", value(point))).foregroundStyle(LinearGradient(colors: [color.opacity(0.14), color.opacity(0.005)], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                LineMark(x: .value("Date", point.date), y: .value("Performance", value(point))).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Baseline", 0)).foregroundStyle(Palette.muted.opacity(0.25)).lineStyle(StrokeStyle(dash: [3, 5]))
            if let selectedDate, let nearest = points.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                RuleMark(x: .value("Selected", nearest.date)).foregroundStyle(Palette.muted).annotation(position: .top, alignment: .leading) { Text(Format.number(value(nearest))).font(.caption.monospaced()).padding(6).background(Palette.raised, in: RoundedRectangle(cornerRadius: 5)) }
            }
        }.chartXSelection(value: $selectedDate).chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine().foregroundStyle(Palette.muted.opacity(0.1)); AxisValueLabel().foregroundStyle(Palette.muted) } }.chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Palette.muted) } }.frame(height: height).animation(store.preferences.animations && !reduceMotion ? .easeInOut(duration: 0.25) : nil, value: points.count)
        .accessibilityLabel("\(mode.rawValue) performance curve, \(max(0, points.count - 1)) trades")
        .mask(alignment: .leading) { Rectangle().scaleEffect(x: revealed || !store.preferences.animations || reduceMotion ? 1 : 0, anchor: .leading) }
        .onAppear { withAnimation(store.preferences.animations && !reduceMotion ? .easeOut(duration: 0.3) : nil) { revealed = true } }
    }
}
enum GroupMetric: String, CaseIterable { case averageR = "Average R", winRate = "Win rate", pnl = "Net PnL", expectancy = "Expectancy", profitFactor = "Profit factor" }
struct GroupBarChart: View {
    var groups: [MetricGroup]
    var metric: GroupMetric
    private func value(_ p: Performance) -> Double? { switch metric { case .averageR: return p.averageR; case .winRate: return p.winRate; case .pnl: return p.netPnL; case .expectancy: return p.expectancy; case .profitFactor: return p.profitFactor } }
    var body: some View {
        Chart(groups) { group in
            if let number = value(group.performance) {
                BarMark(x: .value(metric.rawValue, number), y: .value("Group", group.name)).foregroundStyle(Palette.outcome(number).opacity(0.8)).cornerRadius(3).annotation(position: .trailing) { Text(Format.number(number, digits: 1)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted) }
            }
        }.chartXAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Palette.muted.opacity(0.1)); AxisValueLabel().foregroundStyle(Palette.muted) } }.chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Palette.muted) } }.frame(height: max(160, CGFloat(groups.count) * 33))
    }
}
struct PerformanceHeatmap: View {
    var trades: [TradeRecord]
    var calendar: Calendar
    private var buckets: [Int: Performance] {
        let grouped = Dictionary(grouping: trades) { t in calendar.component(.weekday, from: t.date) * 100 + calendar.component(.hour, from: t.date) * 2 + (calendar.component(.minute, from: t.date) >= 30 ? 1 : 0) }
        return grouped.mapValues { AnalyticsEngine.performance($0) }
    }
    var body: some View {
        let values = buckets
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) { Text("DAY").frame(width: 36, alignment: .leading); ForEach(19...32, id: \.self) { slot in Text(String(format: "%02d:%02d", slot / 2, slot % 2 * 30)).frame(maxWidth: .infinity) } }.font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
            ForEach(2...6, id: \.self) { day in
                HStack(spacing: 5) {
                    Text(calendar.shortWeekdaySymbols[day - 1]).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 36, alignment: .leading)
                    ForEach(19...32, id: \.self) { slot in
                        let p = values[day * 100 + slot]; let r = p?.averageR
                        Text(r.map { Format.number($0, digits: 1) } ?? "·").font(.system(size: 9, design: .monospaced)).foregroundStyle(r.map { Palette.outcome($0) } ?? Palette.muted.opacity(0.35)).frame(maxWidth: .infinity).frame(height: 30).background(r.map { Palette.outcome($0).opacity(min(0.35, 0.07 + abs($0) * 0.09)) } ?? Palette.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 4)).help("\(calendar.weekdaySymbols[day - 1]) · n = \(p?.count ?? 0) · \(Format.r(r))")
                    }
                }
            }
            Text("Average R · half-hour entry buckets · \(calendar.timeZone.identifier)").font(.system(size: 9)).foregroundStyle(Palette.muted)
        }
    }
}
