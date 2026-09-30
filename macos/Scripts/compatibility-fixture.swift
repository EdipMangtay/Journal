import Foundation
@testable import LiquidityEdge

@main struct CompatibilityFixture {
    @MainActor static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "validate" {
            let backup = try BackupService.decode(Data(contentsOf: destination))
            let store = try JournalStore(demo: false, storageURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store"))
            try BackupService.restore(backup, into: store)
            guard Set(store.trades) == Set(backup.trades) else { throw JournalError(message: "Trade fields changed during restore") }
            for item in backup.screenshots {
                guard let model = store.model(item.tradeID)?.screenshots.first(where: { $0.id == item.screenshot.id }), try ScreenshotDraft(model) == item.screenshot else { throw JournalError(message: "Image or annotation changed during restore") }
            }
            print("Validated and restored \(store.trades.count) Windows trades in SwiftData.")
            return
        }
        let store = try JournalStore(demo: true)
        let archive = try BackupService.archive(store)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try BackupService.encode(archive).write(to: destination.appendingPathComponent("macos-backup.json"))
        let p = AnalyticsEngine.performance(archive.trades)
        let metrics: [String: Double] = ["count": Double(p.count), "wins": Double(p.wins), "losses": Double(p.losses), "netPnL": p.netPnL, "totalR": p.totalR, "maxDrawdown": p.maxDrawdown, "compliance": p.compliance, "executionScore": p.executionScore, "winRate": p.winRate, "expectancy": p.expectancy]
        try JSONEncoder().encode(metrics).write(to: destination.appendingPathComponent("macos-metrics.json"))
        print("Exported \(archive.trades.count) demo trades for compatibility tests.")
    }
}
