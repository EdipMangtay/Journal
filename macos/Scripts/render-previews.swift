import SwiftUI
import AppKit

@main struct RenderPreviews {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let store = try JournalStore(demo: true)
        store.preferences.animations = false
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render<V: View>(_ name: String, _ view: V, width: CGFloat = 1440, height: CGFloat = 1000) throws {
            let content = view.environment(store).environment(\.locale, L10n.locale).environment(\.colorScheme, .dark).environment(\.timeZone, store.preferences.calendar.timeZone).frame(width: width, height: height).background(Palette.canvas)
            let host = NSHostingView(rootView: content)
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw JournalError(message: "Could not allocate \(name)") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw JournalError(message: "Could not render \(name)") }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            print("Rendered \(name)")
        }
        try render("dashboard", RootView(startJournal: {}, openDemo: {}))
        try render("analytics", AnalyticsView(mode: .analytics), width: 1225)
        try render("calendar", CalendarView(openTrade: { _ in }), width: 1225)
        try render("trade-editor", TradeEditorView(record: store.trades.first), width: 960, height: 860)
        try render("trade-detail", TradeDetailView(tradeID: store.trades[0].id, edit: { _ in }), width: 1040, height: 860)
        try render("playbook", PlaybookView(), width: 1225)
        try render("reviews", ReviewsView(), width: 1225)
        try render("settings", SettingsView(openDemo: {}), width: 1225)
        try render("screenshots", ScreenshotLibraryView(openTrade: { _ in }), width: 1225)
        try render("mistakes", MistakesView(), width: 1225)
        try render("statistics", AnalyticsView(mode: .statistics), width: 1225)
    }
}
