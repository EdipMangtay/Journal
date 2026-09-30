import SwiftUI

struct ReviewDraft: Identifiable {
    var id = UUID(), period = "Weekly", date = Date(), worked = "", didNot = "", repeatNext = "", stop = "", adjustment = ""
    init() {}
    init(_ review: Review) { id = review.id; period = review.period; date = review.date; worked = review.worked; didNot = review.didNot; repeatNext = review.repeatNext; stop = review.stop; adjustment = review.adjustment }
}
struct ReviewsView: View {
    @Environment(JournalStore.self) private var store
    @State private var draft: ReviewDraft?
    @State private var deleting: Review?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { PageHeader(eyebrow: "Deliberate practice", title: "Turn experience into improvement.", subtitle: "Daily, weekly and monthly reviews anchored in your trade data."); Spacer(); Button("New review") { draft = ReviewDraft() }.buttonStyle(.borderedProminent) }
            if store.reviews.isEmpty { EmptyJournal(title: "Close the feedback loop.", subtitle: "Summarize what worked, identify the recurring mistake, and choose one adjustment.", actionTitle: "Start a review", action: { draft = ReviewDraft() }) }
            ForEach(store.reviews, id: \.id) { review in
                Panel {
                    HStack { VStack(alignment: .leading, spacing: 8) { Badge(text: review.period.uppercased(), color: Palette.blue); Text(Format.date(review.date, calendar: store.preferences.calendar)).font(.title3); Text(review.adjustment.isEmpty ? "No adjustment recorded" : review.adjustment).font(.callout).foregroundStyle(Palette.muted) }; Spacer(); Button("Open review") { draft = ReviewDraft(review) }; Button { deleting = review } label: { Image(systemName: "trash") } }
                }
            }
        }.pagePadding() }.sheet(item: $draft) { initial in ReviewEditor(initial: initial).environment(store) }
        .confirmationDialog("Delete this review?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) { Button("Delete review", role: .destructive) { if let deleting { do { try store.commit { store.context.delete(deleting) } } catch { store.report(error) } }; deleting = nil } }
    }
}
struct ReviewEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReviewDraft
    @State private var error: String?
    init(initial: ReviewDraft) { _draft = State(initialValue: initial) }
    private var interval: DateInterval { store.preferences.calendar.dateInterval(of: draft.period == "Daily" ? .day : draft.period == "Monthly" ? .month : .weekOfYear, for: draft.date)! }
    var body: some View {
        let trades = store.trades.filter { interval.contains($0.date) }, p = AnalyticsEngine.performance(trades)
        let setups = AnalyticsEngine.groups(trades, by: .setup, calendar: store.preferences.calendar).sorted { ($0.performance.averageR ?? -.infinity) > ($1.performance.averageR ?? -.infinity) }
        let best = trades.max { $0.netPnL < $1.netPnL }, worst = trades.min { $0.netPnL < $1.netPnL }
        VStack(spacing: 0) {
            HStack { Text("Performance review").font(.title2); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save review", action: save).buttonStyle(.borderedProminent) }.padding(24)
            ScrollView { VStack(alignment: .leading, spacing: 20) {
                HStack { Picker("Period", selection: $draft.period) { ForEach(["Daily", "Weekly", "Monthly"], id: \.self) { Text($0) } }; DatePicker("Contains date", selection: $draft.date, displayedComponents: .date) }
                Text("\(Format.date(interval.start, calendar: store.preferences.calendar)) — \(Format.date(interval.end.addingTimeInterval(-1), calendar: store.preferences.calendar)) · Live statistics").font(.caption).foregroundStyle(Palette.muted)
                HStack { MetricCard(title: "Trades", value: "\(p.count)"); MetricCard(title: "Net PnL", value: Format.money(p.netPnL, currency: store.preferences.currency)); MetricCard(title: "R", value: Format.r(p.totalR)) }
                Panel(title: "REVIEW SNAPSHOT") {
                    row("WR / PF / Expectancy", "\(Format.percent(p.winRate)) / \(Format.factor(p)) / \(Format.r(p.averageR))")
                    row("Best setup", setups.first?.name ?? "—"); row("Worst setup", setups.last?.name ?? "—")
                    row("Best trade", best.map { "\($0.instrument) · \(Format.money($0.netPnL, currency: store.preferences.currency))" } ?? "—")
                    row("Worst trade", worst.map { "\($0.instrument) · \(Format.money($0.netPnL, currency: store.preferences.currency))" } ?? "—")
                    row("Most common mistake", AnalyticsEngine.mistakes(trades).first?.name ?? "None recorded")
                    row("Rule compliance / Execution", "\(Format.percent(p.compliance)) / \(Format.number(p.executionScore, digits: 0))/100")
                    Text("Setup ranking uses average recorded R. Statistics update when underlying trades change.").font(.caption).foregroundStyle(Palette.muted)
                }
                NoteField(title: "What worked?", text: $draft.worked); NoteField(title: "What didn't?", text: $draft.didNot); NoteField(title: "What should I repeat?", text: $draft.repeatNext); NoteField(title: "What should I stop doing?", text: $draft.stop); NoteField(title: "What is one adjustment for the next period?", text: $draft.adjustment)
                if let error { Text(error).foregroundStyle(Palette.amber) }
            }.padding(24) }
        }.frame(width: 850, height: 820).background(Palette.canvas)
    }
    private func row(_ title: String, _ value: String) -> some View { HStack { Text(title).foregroundStyle(Palette.muted); Spacer(); Text(value) }.font(.caption) }
    private func save() {
        do { try store.commit { let review = store.reviews.first { $0.id == draft.id } ?? Review(id: draft.id, period: draft.period, date: draft.date); store.context.insert(review); review.period = draft.period; review.date = draft.date; review.worked = draft.worked; review.didNot = draft.didNot; review.repeatNext = draft.repeatNext; review.stop = draft.stop; review.adjustment = draft.adjustment }; dismiss() } catch { self.error = error.localizedDescription }
    }
}
