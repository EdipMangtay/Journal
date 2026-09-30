import SwiftUI

@MainActor @Observable final class AppRuntime {
    var store: JournalStore?
    var launchError: String?
    init() { load(demo: !UserDefaults.standard.bool(forKey: "journal.started")) }
    func load(demo: Bool) {
        do { let newStore = try JournalStore(demo: demo); store = newStore; launchError = nil; if !demo { UserDefaults.standard.set(true, forKey: "journal.started") } }
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
                    VStack(spacing: 20) { Text("Unable to open your journal").font(.title); Text(runtime.launchError ?? "Unknown storage error").textSelection(.enabled); Button("Retry") { runtime.load(demo: !UserDefaults.standard.bool(forKey: "journal.started")) } }.padding(40)
                }
            }.frame(minWidth: 1060, minHeight: 720)
        }.defaultSize(width: 1440, height: 960).windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { Button("New Trade") { NotificationCenter.default.post(name: .newTrade, object: nil) }.keyboardShortcut("n", modifiers: .command) }
            CommandGroup(after: .newItem) { Button("Search & Commands") { NotificationCenter.default.post(name: .commandPalette, object: nil) }.keyboardShortcut("k", modifiers: .command) }
        }
    }
}