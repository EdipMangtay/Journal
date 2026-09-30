import Foundation
import Observation

@MainActor @Observable final class TradeDraft {
    var record: TradeRecord
    var screenshots: [ScreenshotDraft] = []
    var error: String?
    let isNew: Bool
    init(record: TradeRecord?) { self.record = record ?? TradeRecord(); isNew = record == nil }
    func loadAttachments(from store: JournalStore) {
        do { screenshots = try (store.model(record.id)?.screenshots ?? []).map(ScreenshotDraft.init) }
        catch { self.error = error.localizedDescription }
    }
    func calculateR() {
        guard let risk = record.riskDollars, risk > 0 else { error = "Enter positive dollar risk to calculate net R."; return }
        record.rMultiple = record.netPnL / risk
    }
    func save(into store: JournalStore) -> Bool {
        do { try store.save(record, screenshots: screenshots); return true }
        catch { self.error = error.localizedDescription; return false }
    }
}
