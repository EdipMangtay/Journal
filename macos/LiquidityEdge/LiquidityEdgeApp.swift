import SwiftUI

@MainActor @Observable final class AppRuntime {
    var store: JournalStore?
    var launchError: String?
    init() { load(demo: false) }
    func load(demo: Bool) {
        do {
            var storageURL: URL?
            if !demo, let directory = ProcessInfo.processInfo.environment["JOURNAL_TEST_DATA_DIR"] {
                let folder = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                storageURL = folder.appendingPathComponent("Journal.store")
            }
            let newStore = try JournalStore(demo: demo, storageURL: storageURL)
            store = newStore; launchError = nil
            if !demo && storageURL == nil { UserDefaults.standard.set(true, forKey: "journal.started") }
        }
        catch { launchError = error.localizedDescription }
    }
}
@main struct LiquidityEdgeApp: App {
    @State private var runtime = AppRuntime()
    var body: some Scene {
        Window("LIQUIDITY EDGE", id: "main") {
            Group {
                if let store = runtime.store {
                    RootView(startJournal: { runtime.load(demo: false) }, openDemo: { runtime.load(demo: true) })
                        .environment(store).id(ObjectIdentifier(store))
                        .preferredColorScheme(store.preferences.theme == "System" ? nil : store.preferences.theme == "Light" ? .light : .dark)
                } else {
                    VStack(spacing: 20) { Text("Unable to open your journal").font(.title); Text(runtime.launchError ?? "Unknown storage error").textSelection(.enabled); Button("Retry") { runtime.load(demo: false) } }.padding(40)
                }
            }.frame(minWidth: 1060, minHeight: 720)
        }.defaultSize(width: 1440, height: 960).windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { Button("New Trade") { NotificationCenter.default.post(name: .newTrade, object: nil) }.keyboardShortcut("n", modifiers: .command) }
            CommandGroup(after: .newItem) { Button("Search & Commands") { NotificationCenter.default.post(name: .commandPalette, object: nil) }.keyboardShortcut("k", modifiers: .command) }
        }
    }
}
