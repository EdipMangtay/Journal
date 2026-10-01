import SwiftUI

struct TradeEditorView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TradeDraft
    @State private var customRule = ""
    @State private var customMarket = ""
    @State private var tags = ""
    @State private var loaded = false
    @State private var quickSetup = ""
    init(record: TradeRecord?) { _draft = State(initialValue: TradeDraft(record: record)) }
    var body: some View {
        @Bindable var draft = draft
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { Text(L10n.text(draft.isNew ? "New execution" : "Edit execution")).font(.title2.weight(.semibold)); Text(L10n.text("Capture the essentials. Expand the context when it matters.")).font(.caption).foregroundStyle(Palette.muted) }
                Spacer(); Button(L10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.text("Save trade")) { draft.record.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }; if draft.save(into: store) { dismiss() } }.buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    general
                    process
                    DisclosureGroup(L10n.text("Prices, risk & duration")) { prices.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Market context & liquidity")) { marketContext.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Quarterly Theory · QT")) { qt.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Market Maker Model · MMXM")) { mmxm.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Power of Three · PO3")) { po3.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("SSMT & TSMO confirmations")) { divergences.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Candle Range Theory · CRT")) { crt.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Entry model & confirmations")) { VStack(alignment: .leading, spacing: 16) { option("Entry timeframe", $draft.record.entryTimeframe, ["15M", "5M", "3M", "1M"]); ChipSelection(options: Catalog.confirmations, selection: $draft.record.confirmations) }.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Execution grading")) { scores.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Emotional journal")) { emotions.padding(.top, 16) }.editorSection()
                    DisclosureGroup(L10n.text("Trade thesis & review notes")) { notes.padding(.top, 16) }.editorSection()
                    Panel(title: "SCREENSHOTS") { ScreenshotAttachmentEditor(shots: $draft.screenshots) }
                    TextField(L10n.text("Tags, separated by commas"), text: $tags).textFieldStyle(.roundedBorder)
                }.padding(24)
            }
            if let error = draft.error { HStack { Image(systemName: "exclamationmark.circle"); Text(L10n.text(error)); Spacer(); Button(L10n.text("Dismiss")) { draft.error = nil } }.font(.caption).foregroundStyle(Palette.amber).padding(16).background(Palette.raised) }
        }.frame(width: 930, height: 820).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
        .onAppear {
            guard !loaded else { return }; loaded = true
            draft.loadAttachments(from: store); tags = draft.record.tags.joined(separator: ", ")
            if draft.isNew { draft.record.riskPercent = store.preferences.defaultRiskPercent; draft.record.riskDollars = store.preferences.accountSize * store.preferences.defaultRiskPercent / 100 }
        }
    }
    private var general: some View {
        @Bindable var draft = draft
        return Panel(title: "01 / THE EXECUTION") {
            HStack(spacing: 20) {
                VStack(alignment: .leading) { Text(L10n.text("Instrument")).font(.caption).foregroundStyle(Palette.muted); TextField(L10n.text("NQ"), text: $draft.record.instrument).textFieldStyle(.roundedBorder); Menu(L10n.text("Choose instrument")) { ForEach(store.instruments.filter(\.enabled), id: \.id) { instrument in Button(instrument.symbol) { draft.record.instrument = instrument.symbol } } }.font(.caption) }
                option("Direction", $draft.record.direction, ["Long", "Short"])
                DatePicker(L10n.text("Entry time"), selection: $draft.record.date).datePickerStyle(.field).frame(minWidth: 240)
            }
            HStack(spacing: 20) {
                number("Gross PnL \(store.preferences.currency)", $draft.record.grossPnL)
                optionalNumber("R multiple", $draft.record.rMultiple)
                option("Session", $draft.record.session, store.preferences.sessions)
            }
            HStack(spacing: 20) {
                Picker(L10n.text("Setup"), selection: $draft.record.setupID) {
                    Text(L10n.text("Unassigned")).tag(nil as UUID?)
                    ForEach(store.setups, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }.onChange(of: draft.record.setupID) { _, value in draft.record.setupName = store.setups.first { $0.id == value }?.name ?? "Unassigned" }
                option("Grade", $draft.record.grade, ["A+", "A", "B", "C", "D", "F"])
            }
            if store.setups.isEmpty {
                HStack {
                    TextField(L10n.text("Name your first setup"), text: $quickSetup).textFieldStyle(.roundedBorder)
                    Button(L10n.text("Create setup")) { createQuickSetup() }
                }
            }
            Text(L10n.text("Gross PnL is before fees. R is optional and can be entered manually or calculated from net PnL and risk.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private var process: some View {
        @Bindable var draft = draft
        return Panel(title: "02 / PROCESS BEFORE OUTCOME") {
            Toggle(L10n.text("Fully according to my trading plan"), isOn: $draft.record.followsPlan).toggleStyle(.switch)
            if !draft.record.followsPlan || !draft.record.brokenRules.isEmpty {
                ChipSelection(options: Catalog.rules + store.customRules.map(\.name) + draft.record.brokenRules, selection: $draft.record.brokenRules)
                HStack { TextField(L10n.text("Custom broken rule"), text: $customRule).textFieldStyle(.roundedBorder); Button(L10n.text("Add")) { let value = customRule.trimmingCharacters(in: .whitespaces); if !value.isEmpty && !draft.record.brokenRules.contains(value) { draft.record.brokenRules.append(value); customRule = "" } } }
            }
            HStack { Badge(text: draft.record.classification.rawValue, color: Palette.classification(draft.record.classification)); Text(L10n.text(draft.record.classification.message)).font(.caption).foregroundStyle(Palette.muted); Spacer() }
        }
    }
    private var prices: some View {
        @Bindable var draft = draft
        return VStack(spacing: 16) {
            HStack { optionalNumber("Entry price", $draft.record.entryPrice); optionalNumber("Stop loss", $draft.record.stopLoss); optionalNumber("Take profit", $draft.record.takeProfit); optionalNumber("Exit price", $draft.record.exitPrice) }
            HStack { optionalNumber("Position size", $draft.record.positionSize); optionalNumber("Risk \(store.preferences.currency)", $draft.record.riskDollars); optionalNumber("Risk %", $draft.record.riskPercent); number("Fees", $draft.record.fees) }
            HStack { Text(L10n.text("Net: \(Format.money(draft.record.netPnL, currency: store.preferences.currency))")); Text(L10n.text("Planned RR: \(draft.record.plannedRR.map { Format.number($0) } ?? "—")")).foregroundStyle(Palette.muted); Spacer(); Button(L10n.text("Calculate R from net PnL")) { draft.calculateR() } }
            HStack { Toggle(L10n.text("Record exit time"), isOn: Binding(get: { draft.record.exitDate != nil }, set: { draft.record.exitDate = $0 ? draft.record.date.addingTimeInterval(1800) : nil })); if draft.record.exitDate != nil { DatePicker(L10n.text("Exit"), selection: Binding(get: { draft.record.exitDate ?? draft.record.date }, set: { draft.record.exitDate = $0 })) }; Spacer() }
        }
    }
    private var marketContext: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            HStack { option("HTF bias", $draft.record.bias, ["Bullish", "Bearish", "Neutral"]); Toggle(L10n.text("HTF alignment"), isOn: $draft.record.htfAligned) }
            Text(L10n.text("Context timeframes")).font(.caption); ChipSelection(options: Catalog.timeframes, selection: $draft.record.contextTimeframes)
            HStack { TextField(L10n.text("Draw on liquidity / custom"), text: $draft.record.drawOnLiquidity).textFieldStyle(.roundedBorder); Menu(L10n.text("Liquidity reference")) { ForEach(Catalog.liquidity, id: \.self) { value in Button(value) { draft.record.drawOnLiquidity = value } } } }
            Text(L10n.text("Liquidity taken")).font(.caption); ChipSelection(options: Catalog.sweeps, selection: $draft.record.liquidityTaken)
            Toggle(L10n.text("Liquidity sweep valid"), isOn: $draft.record.sweepValid)
        }
    }
    private var qt: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            Toggle(L10n.text("QT enabled"), isOn: $draft.record.qt.enabled)
            if draft.record.qt.enabled {
                HStack { option("Higher timeframe quarter", $draft.record.qt.higherQuarter, ["Q1", "Q2", "Q3", "Q4"]); option("Daily quarter", $draft.record.qt.dailyQuarter, ["Q1", "Q2", "Q3", "Q4"]) }
                HStack { option("90 minute cycle", $draft.record.qt.cycle90, ["Q1", "Q2", "Q3", "Q4"]); option("22.5 minute cycle", $draft.record.qt.cycle22, ["Q1", "Q2", "Q3", "Q4"]) }
                option("QT phase", $draft.record.qt.phase, ["Accumulation", "Manipulation", "Distribution", "Continuation"])
                HStack { Toggle(L10n.text("True open respected"), isOn: $draft.record.qt.trueOpen); Toggle(L10n.text("QT bias aligned"), isOn: $draft.record.qt.aligned); Toggle(L10n.text("QT model valid"), isOn: $draft.record.qt.valid) }
            }
        }
    }
    private var mmxm: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            option("MMXM", $draft.record.mmxm.model, ["None", "Market Maker Buy Model", "Market Maker Sell Model"])
            if draft.record.mmxm.model != "None" {
                HStack { Toggle(L10n.text("Original consolidation"), isOn: $draft.record.mmxm.consolidation); Toggle(L10n.text("Manipulation"), isOn: $draft.record.mmxm.manipulation); Toggle(L10n.text("Displacement"), isOn: $draft.record.mmxm.displacement) }
                HStack { Toggle(L10n.text("Repricing"), isOn: $draft.record.mmxm.repricing); Toggle(L10n.text("Smart money reversal"), isOn: $draft.record.mmxm.reversal); Toggle(L10n.text("Opposing liquidity target"), isOn: $draft.record.mmxm.target) }
                Toggle(L10n.text("MMXM valid"), isOn: $draft.record.mmxm.valid)
            }
        }
    }
    private var po3: some View {
        @Bindable var draft = draft
        return HStack { option("PO3 phase", $draft.record.po3.phase, ["Accumulation", "Manipulation", "Distribution"]); option("Manipulation direction", $draft.record.po3.manipulationDirection, ["Up", "Down"]); Toggle(L10n.text("PO3 valid"), isOn: $draft.record.po3.valid) }
    }
    private var divergences: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            HStack { option("SSMT confirmation", $draft.record.ssmt.confirmation, ["Yes", "No", "Not Required"]); Toggle(L10n.text("Valid SSMT"), isOn: $draft.record.ssmt.valid) }
            option("SSMT type", $draft.record.ssmt.type, ["High divergence", "Low divergence", "Intermarket divergence", "Time-based divergence"])
            ChipSelection(options: ["NQ", "ES", "YM", "DXY", "Gold", "EUR", "GBP"] + draft.record.ssmt.markets, selection: $draft.record.ssmt.markets)
            HStack { TextField(L10n.text("Custom reference market"), text: $customMarket).textFieldStyle(.roundedBorder); Button(L10n.text("Add market")) { let text = customMarket.trimmingCharacters(in: .whitespaces); if !text.isEmpty { if !draft.record.ssmt.markets.contains(text) { draft.record.ssmt.markets.append(text) }; customMarket = "" } } }
            Divider()
            HStack { option("TSMO confirmation", $draft.record.tsmo, ["Yes", "No", "Not Required"]); Toggle(L10n.text("TSMO valid"), isOn: $draft.record.tsmoValid) }
            Text(L10n.text("A confirmation contributes to analytics only when it is both present and valid.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private var crt: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            Toggle(L10n.text("CRT setup"), isOn: $draft.record.crt.enabled)
            if draft.record.crt.enabled {
                HStack { option("CRT timeframe", $draft.record.crt.timeframe, Catalog.timeframes); optionalNumber("Range high", $draft.record.crt.high); optionalNumber("Range low", $draft.record.crt.low) }
                HStack { option("Liquidity taken", $draft.record.crt.liquidityTaken, ["High", "Low"]); Toggle(L10n.text("CRT re-entry"), isOn: $draft.record.crt.reentry); Toggle(L10n.text("CRT confirmed"), isOn: $draft.record.crt.confirmed) }
            }
        }
    }
    private var scores: some View {
        @Bindable var draft = draft
        return VStack(spacing: 12) {
            ScoreSlider(title: "Market read", value: $draft.record.scores.marketRead)
            ScoreSlider(title: "Entry execution", value: $draft.record.scores.entry)
            ScoreSlider(title: "Rule compliance", value: $draft.record.scores.compliance)
            ScoreSlider(title: "Risk management", value: $draft.record.scores.risk)
            ScoreSlider(title: "Trade management", value: $draft.record.scores.management)
            ScoreSlider(title: "Psychology", value: $draft.record.scores.psychology)
            ScoreSlider(title: "Pattern recognition", value: $draft.record.scores.recognition)
            HStack { Text(L10n.text("Overall score")); Spacer(); Text(L10n.text("\(Format.number(draft.record.scores.overall, digits: 0)) / 100")).foregroundStyle(Palette.mint).font(.title3.monospaced()) }
        }
    }
    private var emotions: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("BEFORE")).font(.caption.monospaced()).foregroundStyle(Palette.muted)
            ScoreSlider(title: "Confidence", value: $draft.record.emotional.confidence, lower: 1)
            ScoreSlider(title: "Stress", value: $draft.record.emotional.stress, lower: 1)
            ScoreSlider(title: "FOMO", value: $draft.record.emotional.fomo, lower: 1)
            ScoreSlider(title: "Focus", value: $draft.record.emotional.focus, lower: 1)
            Text(L10n.text("AFTER")).font(.caption.monospaced()).foregroundStyle(Palette.muted)
            ScoreSlider(title: "Execution satisfaction", value: $draft.record.emotional.satisfaction, lower: 1)
            Toggle(L10n.text("I would take this trade again"), isOn: $draft.record.emotional.takeAgain)
            ChipSelection(options: Catalog.emotions, selection: $draft.record.emotional.emotions)
        }
    }
    private var notes: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 16) {
            NoteField(title: "Trade thesis", text: $draft.record.notes.thesis)
            NoteField(title: "Why did I enter?", text: $draft.record.notes.entry)
            NoteField(title: "What confirmed the trade?", text: $draft.record.notes.confirmation)
            NoteField(title: "What invalidated the setup?", text: $draft.record.notes.invalidation)
            NoteField(title: "What did I do correctly?", text: $draft.record.notes.correct)
            NoteField(title: "What did I do incorrectly?", text: $draft.record.notes.incorrect)
            NoteField(title: "What would I do differently?", text: $draft.record.notes.differently)
            NoteField(title: "Key lesson", text: $draft.record.notes.lesson)
        }
    }
    private func option(_ title: String, _ binding: Binding<String>, _ options: [String]) -> some View { Picker(L10n.text(title), selection: binding) { ForEach(Array(Set(options + [binding.wrappedValue])).sorted(), id: \.self) { Text(L10n.text($0)).tag($0) } }.frame(maxWidth: .infinity) }
    private func createQuickSetup() {
        let name = quickSetup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { draft.error = "Give your setup a name."; return }
        do {
            let setup = Setup(name: name)
            try store.commit { store.context.insert(setup); let book = Playbook(); store.context.insert(book); setup.playbook = book }
            draft.record.setupID = setup.id; draft.record.setupName = name; quickSetup = ""
        } catch { draft.error = error.localizedDescription }
    }
    private func number(_ title: String, _ binding: Binding<Double>) -> some View { VStack(alignment: .leading, spacing: 6) { Text(L10n.text(title)).font(.caption).foregroundStyle(Palette.muted); TextField(L10n.text(title), value: binding, format: .number).textFieldStyle(.roundedBorder) } }
    private func optionalNumber(_ title: String, _ binding: Binding<Double?>) -> some View { VStack(alignment: .leading, spacing: 6) { Text(L10n.text(title)).font(.caption).foregroundStyle(Palette.muted); TextField(L10n.text(title), value: binding, format: .number).textFieldStyle(.roundedBorder) } }
}
struct NoteField: View {
    var title: String
    @Binding var text: String
    var body: some View { VStack(alignment: .leading, spacing: 8) { Text(L10n.text(title)).font(.caption).foregroundStyle(Palette.muted); TextEditor(text: $text).font(.system(size: 13)).scrollContentBackground(.hidden).padding(8).frame(minHeight: 85).background(Palette.raised, in: RoundedRectangle(cornerRadius: 7)) } }
}
private extension View {
    func editorSection() -> some View { self.font(.system(size: 13, weight: .medium)).padding(18).background(Palette.panel, in: RoundedRectangle(cornerRadius: 10)) }
}
