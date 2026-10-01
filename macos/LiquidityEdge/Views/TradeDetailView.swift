import SwiftUI

struct TradeDetailView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var tradeID: UUID
    var edit: (TradeRecord) -> Void
    @State private var deleting = false
    @State private var selectedImage: ScreenshotDraft?
    private var trade: TradeRecord? { store.trades.first { $0.id == tradeID } }
    var body: some View {
        VStack(spacing: 0) {
            if let t = trade {
                HStack { Text(L10n.text("EXECUTION REVIEW")).font(.caption.monospaced()).tracking(2).foregroundStyle(Palette.muted); Spacer(); Button(L10n.text("Delete"), role: .destructive) { deleting = true }; Button(L10n.text("Edit trade")) { edit(t) }; Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction) }.padding(24)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 12) { HStack { Text(t.instrument).font(.system(size: 40, weight: .semibold)).tracking(-1.5); Badge(text: t.direction.uppercased(), color: Palette.blue); Badge(text: t.grade) }; Text(t.setupID == nil ? L10n.text(t.setupName) : t.setupName).font(.title3).foregroundStyle(Palette.muted); HStack { Text(Format.date(t.date, calendar: store.preferences.calendar, time: true)); Text("· " + L10n.text(t.session)) }.font(.caption).foregroundStyle(Palette.muted) }
                            Spacer(); VStack(alignment: .trailing, spacing: 8) { Text(Format.r(t.rMultiple)).font(.system(size: 42, weight: .light, design: .rounded)).foregroundStyle(Palette.outcome(t.rMultiple ?? 0)); Text(Format.money(t.netPnL, currency: store.preferences.currency)).font(.title2).foregroundStyle(Palette.outcome(t.netPnL)) }
                        }
                        Panel {
                            HStack { Badge(text: t.classification.rawValue, color: Palette.classification(t.classification)); Text(L10n.text(t.classification.message)).font(.callout); Spacer() }
                            if !t.compliant { Text(t.brokenRules.map(L10n.text).joined(separator: " · ")).font(.caption).foregroundStyle(Palette.amber) }
                        }
                        Panel(title: "EXECUTION SEQUENCE") {
                            HStack(spacing: 0) {
                                node("HTF", t.bias, t.htfAligned)
                                node("LIQUIDITY", t.liquidityTaken.first ?? "Unspecified", t.sweepValid)
                                node("QT", t.qt.enabled ? t.qt.dailyQuarter : "Not used", t.hasQT)
                                node("SSMT", t.ssmt.confirmation, t.hasSSMT)
                                node("CRT", t.crt.enabled ? t.crt.timeframe : "Not used", t.hasCRT)
                                node("CISD", t.entryTimeframe, t.confirmations.contains("CISD"))
                                node("ENTRY", t.direction, t.compliant)
                                node("TARGET", t.drawOnLiquidity.isEmpty ? "Unspecified" : t.drawOnLiquidity, !t.brokenRules.contains("Ignored target"), last: true)
                            }
                            Text(L10n.text("Green: confirmed · Amber: absent or unconfirmed · Red: broken execution. These are your recorded observations.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        HStack { MetricCard(title: "Overall process", value: "\(Format.number(t.scores.overall, digits: 0))/100"); MetricCard(title: "Risk", value: t.riskDollars.map { Format.money($0, currency: store.preferences.currency) } ?? "—"); MetricCard(title: "Planned RR", value: t.plannedRR.map { Format.number($0) } ?? "—"); MetricCard(title: "Duration", value: t.duration.map { "\(Int($0 / 60)) min" } ?? "—") }
                        Panel(title: "THESIS & LESSON") { readNote("Trade thesis", t.notes.thesis); readNote("Key lesson", t.notes.lesson) }
                        Panel(title: "VISUAL REVIEW") {
                            let shots = store.model(t.id)?.screenshots ?? []
                            if shots.isEmpty { Text(L10n.text("No screenshots attached. Use Edit trade to add images.")).font(.caption).foregroundStyle(Palette.muted) }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 14) {
                                ForEach(shots, id: \.id) { shot in Button { do { selectedImage = try ScreenshotDraft(shot) } catch { store.report(error) } } label: { VStack(alignment: .leading, spacing: 8) { ScreenshotThumbnail(data: shot.thumbnailData).frame(height: 170); Badge(text: shot.category) } }.buttonStyle(.plain) }
                            }
                        }
                        Panel(title: "CONTEXT & EXECUTION") {
                            detailRow("Prices", "Giriş \(numeric(t.entryPrice)) · Stop \(numeric(t.stopLoss)) · Kâr al \(numeric(t.takeProfit)) · Çıkış \(numeric(t.exitPrice))")
                            detailRow("Size / fees", "\(numeric(t.positionSize)) · \(Format.money(t.fees, currency: store.preferences.currency)) masraf")
                            detailRow("Context timeframes", t.contextTimeframes.map(L10n.text).joined(separator: ", "))
                            detailRow("Liquidity taken", t.liquidityTaken.map(L10n.text).joined(separator: ", "))
                            detailRow("QT", "HTF \(t.qt.higherQuarter) · Günlük \(t.qt.dailyQuarter) · 90 dk \(t.qt.cycle90) · 22,5 dk \(t.qt.cycle22) · \(L10n.text(t.qt.phase))")
                            detailRow("MMXM", L10n.text(t.mmxm.model) + (t.mmxm.valid ? " · Geçerli" : " · Teyitsiz"))
                            detailRow("PO3", L10n.text(t.po3.phase) + " · Manipülasyon " + L10n.text(t.po3.manipulationDirection) + (t.po3.valid ? " · Geçerli" : " · Teyitsiz"))
                            detailRow("SSMT", L10n.text(t.ssmt.type) + " · " + t.ssmt.markets.joined(separator: ", ") + (t.hasSSMT ? " · Geçerli" : " · Teyitsiz"))
                            detailRow("TSMO", L10n.text(t.tsmo) + (t.tsmoValid ? " · Geçerli" : " · Teyitsiz"))
                            detailRow("CRT", "\(t.crt.timeframe) · Aralık \(numeric(t.crt.low)) – \(numeric(t.crt.high)) · \(L10n.text(t.crt.liquidityTaken)) alındı")
                            detailRow("Confirmations", t.confirmations.map(L10n.text).joined(separator: ", "))
                            detailRow("Tags", t.tags.joined(separator: ", "))
                        }
                        Panel(title: "EXECUTION SCORES") {
                            detailRow("Market / Entry / Rules", "\(Int(t.scores.marketRead)) / \(Int(t.scores.entry)) / \(Int(t.scores.compliance))")
                            detailRow("Risk / Management", "\(Int(t.scores.risk)) / \(Int(t.scores.management))")
                            detailRow("Psychology / Recognition", "\(Int(t.scores.psychology)) / \(Int(t.scores.recognition))")
                        }
                        Panel(title: "EMOTIONAL JOURNAL") {
                            detailRow("Before", "Güven \(Int(t.emotional.confidence)) · Stres \(Int(t.emotional.stress)) · FOMO \(Int(t.emotional.fomo)) · Odak \(Int(t.emotional.focus))")
                            detailRow("After", "Uygulamadan memnuniyet \(Int(t.emotional.satisfaction))/10 · Tekrar yaparım: \(t.emotional.takeAgain ? "Evet" : "Hayır")")
                            detailRow("Emotions", t.emotional.emotions.map(L10n.text).joined(separator: ", "))
                        }
                        Panel(title: "REFLECTION") {
                            readNote("Why I entered", t.notes.entry); readNote("What confirmed the trade", t.notes.confirmation); readNote("What invalidated the setup", t.notes.invalidation); readNote("What I did correctly", t.notes.correct); readNote("What I did incorrectly", t.notes.incorrect); readNote("What I would do differently", t.notes.differently)
                        }
                    }.padding(24)
                }
            }
        }.frame(width: 1000, height: 820).background(Palette.canvas).foregroundStyle(Palette.ink)
        .confirmationDialog(L10n.text("Delete this trade and its screenshots?"), isPresented: $deleting) { Button(L10n.text("Delete trade"), role: .destructive) { do { try store.deleteTrade(tradeID); dismiss() } catch { store.report(error) } } } message: { Text(L10n.text("This action cannot be undone. A saved backup can restore the trade.")) }
        .sheet(item: $selectedImage) { shot in ScreenshotViewer(initial: shot) { changed in
            guard let t = trade else { return }; do { var all = try (store.model(t.id)?.screenshots ?? []).map(ScreenshotDraft.init); if let index = all.firstIndex(where: { $0.id == changed.id }) { all[index] = changed }; try store.save(t, screenshots: all) } catch { store.report(error) }
        } }
    }
    private func numeric(_ value: Double?) -> String { value.map { Format.number($0) } ?? "—" }
    private func detailRow(_ title: String, _ value: String) -> some View { HStack(alignment: .top) { Text(L10n.text(title)).foregroundStyle(Palette.muted).frame(width: 180, alignment: .leading); Text(value.isEmpty ? L10n.text("Not recorded") : value).textSelection(.enabled); Spacer(minLength: 0) }.font(.caption) }
    private func readNote(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 7) { Text(L10n.text(title)).font(.caption).foregroundStyle(Palette.muted); Text(text.isEmpty ? L10n.text("Not recorded") : text).font(.system(size: 13)).textSelection(.enabled) } }
    private func node(_ title: String, _ text: String, _ valid: Bool, last: Bool = false) -> some View {
        let color = valid ? Palette.mint : title == "ENTRY" ? Palette.red : Palette.amber
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) { Circle().strokeBorder(color, lineWidth: 1).background(Circle().fill(color.opacity(0.12))).frame(width: 23, height: 23).overlay(Image(systemName: valid ? "checkmark" : "minus").font(.system(size: 9)).foregroundStyle(color)); Rectangle().fill(last ? .clear : Palette.muted.opacity(0.2)).frame(height: 1) }
            Text(L10n.text(title)).font(.system(size: 9, weight: .medium, design: .monospaced)); Text(L10n.text(text)).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(2).frame(height: 25, alignment: .top)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
