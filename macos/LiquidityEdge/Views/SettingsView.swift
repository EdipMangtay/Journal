import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    var openDemo: () -> Void
    @State private var preferences = JournalPreferences()
    @State private var customInstrument = ""
    @State private var customRule = ""
    @State private var customSession = ""
    @State private var importing = false
    @State private var csvImport = false
    @State private var pendingBackup: JournalBackup?
    @State private var pendingCSV: String?
    @State private var previewCount = 0
    @State private var confirmingImport = false
    @State private var message: String?
    @State private var loaded = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeader(eyebrow: "Workspace preferences", title: "Make it your journal.", subtitle: "Local storage, clear defaults and data you control.")
            Panel(title: "ACCOUNT & APPEARANCE") {
                HStack { TextField("Default account size", value: $preferences.accountSize, format: .number); TextField("Default risk %", value: $preferences.defaultRiskPercent, format: .number); TextField("Currency", text: $preferences.currency).frame(width: 130) }.textFieldStyle(.roundedBorder)
                HStack { Picker("Theme", selection: $preferences.theme) { ForEach(["Dark", "Light", "System"], id: \.self) { Text($0) } }; Toggle("Animations", isOn: $preferences.animations); Spacer() }
                TextField("Trading time zone", text: $preferences.timezone).textFieldStyle(.roundedBorder)
                Text("Use an IANA time zone, such as America/New_York or Europe/Istanbul. Calendar and hour analytics use this zone; timestamps are stored as absolute instants. Currency changes display units and does not convert values.").font(.caption).foregroundStyle(Palette.muted)
                Button("Save preferences", action: savePreferences).buttonStyle(.borderedProminent)
            }
            Panel(title: "TRADING SESSIONS") {
                ForEach(preferences.sessions, id: \.self) { session in
                    HStack { Text(session).frame(width: 140, alignment: .leading); TextField("Session hours", text: Binding(get: { preferences.sessionHours[session] ?? "" }, set: { preferences.sessionHours[session] = $0 })).textFieldStyle(.roundedBorder); Button { preferences.sessions.removeAll { $0 == session }; preferences.sessionHours.removeValue(forKey: session) } label: { Image(systemName: "minus.circle") } }
                }
                HStack { TextField("Custom session", text: $customSession).textFieldStyle(.roundedBorder); Button("Add session") { let name = customSession.trimmingCharacters(in: .whitespaces); if !name.isEmpty && !preferences.sessions.contains(name) { preferences.sessions.append(name); preferences.sessionHours[name] = ""; customSession = "" } } }
                Text("Session hours are your reference schedule. Choose the session explicitly on each trade. Save preferences to apply changes.").font(.caption).foregroundStyle(Palette.muted)
            }
            Panel(title: "ALLOWED INSTRUMENTS") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading) {
                    ForEach(store.instruments, id: \.id) { instrument in Toggle(instrument.symbol, isOn: Binding(get: { instrument.enabled }, set: { value in do { try store.commit { instrument.enabled = value } } catch { store.report(error) } })) }
                }
                HStack { TextField("Custom symbol", text: $customInstrument).textFieldStyle(.roundedBorder); Button("Add instrument", action: addInstrument) }
            }
            Panel(title: "CUSTOM RULES") {
                ForEach(store.customRules, id: \.id) { rule in HStack { Text(rule.name); Spacer(); Button { do { try store.commit { store.context.delete(rule) } } catch { store.report(error) } } label: { Image(systemName: "trash") } } }
                HStack { TextField("Rule name", text: $customRule).textFieldStyle(.roundedBorder); Button("Add rule", action: addRule) }
                Text("Custom setups and their rule definitions are managed in Playbook.").font(.caption).foregroundStyle(Palette.muted)
            }
            Panel(title: "DATA & BACKUP", subtitle: "NO CLOUD · NO ACCOUNT REQUIRED") {
                Text("A JSON backup includes every trade, screenshot, annotation, playbook, review, instrument, custom rule and saved preference.").font(.callout)
                HStack { Button("Export CSV") { export(csv: true) }; Button("Export JSON / Create backup") { export(csv: false) }; Button("Import CSV…") { csvImport = true; importing = true }; Button("Restore backup…") { csvImport = false; importing = true } }
                Text("Restore merges by trade ID and replaces matching records. Other trades remain. Review the import count before applying. CSV preserves all trade fields in record_json; screenshots and playbooks require JSON backup.").font(.caption).foregroundStyle(Palette.muted)
                Text("Store: " + ((try? JournalStore.defaultStoreURL().path) ?? "Application Support/LiquidityEdge")).font(.caption.monospaced()).foregroundStyle(Palette.muted).textSelection(.enabled)
                if store.isDemo { Badge(text: "DEMO EXPORT CONTAINS SAMPLE DATA", color: Palette.amber) } else { Button("Explore isolated demo", action: openDemo) }
            }
            if let message { Label(message, systemImage: "info.circle").font(.callout).foregroundStyle(Palette.mint).textSelection(.enabled) }
            Panel(title: "LIQUIDITY EDGE / 1.0") { Text("Professional Trading Performance Journal\nBuilt around discipline, pattern recognition and execution quality.").font(.callout).foregroundStyle(Palette.muted) }
        }.pagePadding() }
        .onAppear { if !loaded { preferences = store.preferences; loaded = true } }
        .fileImporter(isPresented: $importing, allowedContentTypes: csvImport ? [.commaSeparatedText, .plainText] : [.json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 512_000_000 else { throw JournalError(message: "Import is limited to 512 MB.") }
                let data = try Data(contentsOf: url)
                if csvImport { guard let text = String(data: data, encoding: .utf8) else { throw JournalError(message: "CSV must use UTF-8 encoding.") }; let records = try CSVCodec.decode(text); for record in records { if let error = record.validationError { throw JournalError(message: error) } }; pendingCSV = text; pendingBackup = nil; previewCount = records.count }
                else { let backup = try BackupService.decode(data); pendingBackup = backup; pendingCSV = nil; previewCount = backup.trades.count }
                confirmingImport = true
            } catch { store.report(error) }
        }
        .confirmationDialog("Import \(previewCount) trades into \(store.isDemo ? "the demo workspace" : "your journal")?", isPresented: $confirmingImport) {
            Button("Import and merge") {
                do { if let backup = pendingBackup { try BackupService.restore(backup, into: store); preferences = store.preferences } else if let csv = pendingCSV { _ = try BackupService.importCSV(csv, into: store) }; message = "Imported \(previewCount) trades successfully." } catch { store.report(error) }
                pendingBackup = nil; pendingCSV = nil
            }
            Button("Cancel", role: .cancel) { pendingBackup = nil; pendingCSV = nil }
        } message: { Text("Matching IDs will be updated. Other trades remain. JSON restore also merges playbooks and reviews and applies saved preferences. Keep a current backup before updating existing records.") }
    }
    private func savePreferences() {
        let original = store.preferences
        do { store.preferences = preferences; try store.savePreferences(); message = "Preferences saved." } catch { store.preferences = original; store.report(error) }
    }
    private func addInstrument() {
        let symbol = customInstrument.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty, !store.instruments.contains(where: { $0.symbol == symbol }) else { return }
        do { try store.commit { store.context.insert(Instrument(symbol: symbol)) }; customInstrument = "" } catch { store.report(error) }
    }
    private func addRule() {
        let name = customRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !store.customRules.contains(where: { $0.name == name }), !Catalog.rules.contains(name) else { return }
        do { try store.commit { store.context.insert(CustomRule(name: name)) }; customRule = "" } catch { store.report(error) }
    }
    private func export(csv: Bool) {
        do {
            let data = csv ? Data(try CSVCodec.export(store.trades).utf8) : try BackupService.encode(BackupService.archive(store))
            let panel = NSSavePanel(); panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]; panel.nameFieldStringValue = "LiquidityEdge-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))\(csv ? ".csv" : ".json")"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic); message = "Exported \(store.trades.count) trades to \(url.lastPathComponent)."
        } catch { store.report(error) }
    }
}
