import SwiftUI

enum JournalPage: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", trades = "Trades", newTrade = "New Trade", calendar = "Calendar", analytics = "Analytics", setups = "Setup Analysis", playbook = "Playbook", mistakes = "Mistakes", screenshots = "Screenshots", statistics = "Statistics", review = "Review", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self { case .dashboard: return "square.grid.2x2"; case .trades: return "list.bullet.rectangle"; case .newTrade: return "plus.app"; case .calendar: return "calendar"; case .analytics: return "chart.xyaxis.line"; case .setups: return "square.stack.3d.up"; case .playbook: return "book.closed"; case .mistakes: return "exclamationmark.shield"; case .screenshots: return "photo.on.rectangle"; case .statistics: return "chart.bar.xaxis"; case .review: return "checkmark.rectangle"; case .settings: return "slider.horizontal.3" }
    }
}
struct EditorRoute: Identifiable { let id = UUID(); var record: TradeRecord? }
struct DetailRoute: Identifiable { var id: UUID }
struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var startJournal: () -> Void
    var openDemo: () -> Void
    @State private var page = JournalPage.dashboard
    @State private var collapsed = false
    @State private var editor: EditorRoute?
    @State private var detail: DetailRoute?
    @State private var palette = false
    @State private var globalQuery = ""
    private var animation: Animation? { store.preferences.animations && !reduceMotion ? .easeInOut(duration: 0.2) : nil }
    var body: some View {
        @Bindable var store = store
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.muted.opacity(0.12)).frame(width: 1)
            VStack(spacing: 0) {
                topbar
                if store.isDemo {
                    HStack(spacing: 12) { Badge(text: "DEMO WORKSPACE", color: Palette.amber); Text("Explore 28 sample trades. Your real journal stays separate.").font(.caption).foregroundStyle(Palette.muted); Spacer(); Button("Start My Journal", action: startJournal).buttonStyle(.bordered).controlSize(.small) }.padding(.horizontal, 28).padding(.vertical, 10).background(Palette.amber.opacity(0.035))
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity).id(page).transition(.opacity)
            }
        }.background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
        .animation(animation, value: page).animation(animation, value: collapsed).animation(animation, value: store.revision)
        .sheet(item: $editor) { route in TradeEditorView(record: route.record).environment(store) }
        .sheet(item: $detail) { route in TradeDetailView(tradeID: route.id, edit: { record in detail = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { editor = EditorRoute(record: record) } }).environment(store) }
        .sheet(isPresented: $palette) { commandPalette }
        .onReceive(NotificationCenter.default.publisher(for: .newTrade)) { _ in if editor == nil && detail == nil && !palette { editor = EditorRoute() } }
        .onReceive(NotificationCenter.default.publisher(for: .commandPalette)) { _ in if editor == nil && detail == nil { palette = true } }
        .alert("Journal error", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        .environment(\.timeZone, TimeZone(identifier: store.preferences.timezone) ?? .current)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 9).stroke(Palette.mint.opacity(0.5), lineWidth: 1).frame(width: 34, height: 36); Image(systemName: "waveform.path").font(.system(size: 20, weight: .light)).foregroundStyle(Palette.mint) }
                if !collapsed { VStack(alignment: .leading, spacing: 2) { Text("LIQUIDITY").tracking(2); Text("EDGE").tracking(4).foregroundStyle(Palette.muted) }.font(.system(size: 11, weight: .semibold, design: .monospaced)) }
            }.padding(.horizontal, 20).padding(.top, 35).padding(.bottom, 32)
            if !collapsed { Text("WORKSPACE").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.8).foregroundStyle(Palette.muted).padding(.horizontal, 24).padding(.bottom, 12) }
            ForEach(JournalPage.allCases) { item in
                if item == .analytics || item == .review { Divider().overlay(Palette.muted.opacity(0.12)).padding(.horizontal, 20).padding(.vertical, 12) }
                Button { if item == .newTrade { editor = EditorRoute() } else { page = item } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon).font(.system(size: 15, weight: .regular)).frame(width: 20)
                        if !collapsed { Text(item.rawValue).font(.system(size: 12, weight: page == item ? .semibold : .regular)); Spacer(); if item == .newTrade { Text("⌘N").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted) } }
                    }.foregroundStyle(page == item ? Palette.ink : Palette.muted).padding(.horizontal, 12).frame(height: 36).background(page == item ? Palette.raised : .clear, in: RoundedRectangle(cornerRadius: 7)).overlay(alignment: .leading) { if page == item { Capsule().fill(Palette.mint).frame(width: 2, height: 14) } }
                }.buttonStyle(.plain).help(item.rawValue).padding(.horizontal, 12).padding(.vertical, 2)
            }
            Spacer(minLength: 20)
            if !collapsed {
                VStack(alignment: .leading, spacing: 8) { Text("PROCESS > OUTCOME").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1); Text("Protect your process.\nThe edge follows.").font(.caption).foregroundStyle(Palette.muted) }.padding(22)
            }
            Button { collapsed.toggle() } label: { Image(systemName: "sidebar.left").foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading).padding(24) }.buttonStyle(.plain).help("Toggle sidebar")
        }.frame(width: collapsed ? 76 : 215).background(Palette.panel.opacity(0.5))
    }
    private var topbar: some View {
        HStack(spacing: 12) {
            Text("WORKSPACE").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted); Text("/").foregroundStyle(Palette.muted.opacity(0.5)); Text(page.rawValue).font(.system(size: 12))
            Spacer(); Label("LOCAL · PRIVATE", systemImage: "circle.fill").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.mint)
            Button { palette = true } label: { HStack { Image(systemName: "magnifyingglass"); Text("Search"); Text("⌘K").foregroundStyle(Palette.muted) }.font(.caption).padding(.horizontal, 10).padding(.vertical, 6).background(Palette.raised, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain)
            Button { editor = EditorRoute() } label: { Label("New trade", systemImage: "plus").font(.system(size: 11, weight: .semibold)) }.buttonStyle(.borderedProminent).tint(Palette.mint).foregroundStyle(Palette.canvas)
        }.padding(.horizontal, 28).frame(height: 58).overlay(alignment: .bottom) { Rectangle().fill(Palette.muted.opacity(0.1)).frame(height: 1) }
    }
    @ViewBuilder private var content: some View {
        switch page {
        case .dashboard: DashboardView(openTrade: openTrade, newTrade: { editor = EditorRoute() })
        case .trades, .newTrade: TradesView(initialQuery: globalQuery, openTrade: openTrade, newTrade: { editor = EditorRoute() })
        case .calendar: CalendarView(openTrade: openTrade)
        case .analytics: AnalyticsView(mode: .analytics)
        case .setups: AnalyticsView(mode: .setups)
        case .statistics: AnalyticsView(mode: .statistics)
        case .mistakes: MistakesView()
        case .playbook: PlaybookView()
        case .screenshots: ScreenshotLibraryView(openTrade: openTrade)
        case .review: ReviewsView()
        case .settings: SettingsView(openDemo: openDemo)
        }
    }
    private func openTrade(_ record: TradeRecord) { detail = DetailRoute(id: record.id) }
    private var commandPalette: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(Palette.mint); TextField("Search trades or jump to a page…", text: $globalQuery).textFieldStyle(.plain).font(.title3); Button("Esc") { palette = false }.keyboardShortcut(.cancelAction) }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(JournalPage.allCases.filter { globalQuery.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(globalQuery) }) { item in
                        Button { palette = false; if item == .newTrade { editor = EditorRoute() } else { page = item } } label: { Label(item.rawValue, systemImage: item.icon).frame(maxWidth: .infinity, alignment: .leading).padding(10) }.buttonStyle(.plain)
                    }
                    Text("TRADES").font(.caption.monospaced()).foregroundStyle(Palette.muted).padding(.top)
                    ForEach(Array(store.trades.filter { TradeSearch.matches($0, query: globalQuery) }.prefix(30))) { trade in
                        Button { palette = false; openTrade(trade) } label: { HStack { Text(trade.instrument).fontWeight(.semibold); Text(trade.setupName).foregroundStyle(Palette.muted); Spacer(); Text(Format.r(trade.rMultiple)).foregroundStyle(Palette.outcome(trade.netPnL)) }.padding(10) }.buttonStyle(.plain)
                    }
                }
            }
            Text("Try “SSMT loser”, “Gold London”, “QT Q3”, “Invalid Winner” or “CRT only”.").font(.caption).foregroundStyle(Palette.muted)
            Button("Show all matching trades") { page = .trades; palette = false }.buttonStyle(.bordered)
        }.padding(24).frame(width: 650, height: 540).background(Palette.panel)
    }
}
