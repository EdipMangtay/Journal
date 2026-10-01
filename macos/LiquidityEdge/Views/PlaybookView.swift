import SwiftUI

struct PlaybookDraft: Identifiable {
    var id = UUID(), name = "", summary = "", conditions = "", entry = "", invalidation = "", target = "", risk = ""
    var images: [ScreenshotDraft] = []
    init() {}
    init(_ setup: Setup) throws { id = setup.id; name = setup.name; summary = setup.summary; if let p = setup.playbook { conditions = p.conditions; entry = p.entryRules; invalidation = p.invalidationRules; target = p.targetRules; risk = p.riskRules; images = try BackupService.decodeImages(p.idealImagesData) } }
}
struct PlaybookView: View {
    @Environment(JournalStore.self) private var store
    @State private var editor: PlaybookDraft?
    @State private var deleting: Setup?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { PageHeader(eyebrow: "Your models", title: "Define it. Execute it. Refine it.", subtitle: "A living playbook, linked to the performance of your actual trades."); Spacer(); Button(L10n.text("New setup")) { editor = PlaybookDraft() }.buttonStyle(.borderedProminent) }
            if store.setups.isEmpty { EmptyJournal(title: "Codify your first setup.", subtitle: "Write the conditions, invalidation and risk rules that make an execution valid.", actionTitle: "Create setup", action: { editor = PlaybookDraft() }) }
            ForEach(Array(store.setups.enumerated()), id: \.element.id) { index, setup in
                let p = AnalyticsEngine.performance(store.trades.filter { $0.setupID == setup.id })
                Panel {
                    HStack(alignment: .top) { VStack(alignment: .leading, spacing: 10) { Text(String(format: "MODEL %02d", index + 1)).font(.caption.monospaced()).tracking(2).foregroundStyle(Palette.mint); Text(setup.name).font(.title2.weight(.medium)); Text(setup.summary).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Button(L10n.text("Edit")) { do { editor = try PlaybookDraft(setup) } catch { store.report(error) } }; Button { deleting = setup } label: { Image(systemName: "trash") }.help(L10n.text("Delete setup")) }
                    HStack(spacing: 24) { stat("SAMPLES", "\(p.count)"); stat("WIN RATE", Format.percent(p.winRate)); stat("AVG R", Format.r(p.averageR)); stat("EXPECTANCY", Format.money(p.expectancy, currency: store.preferences.currency)); stat("COMPLIANCE", Format.percent(p.compliance)) }
                    if let book = setup.playbook { DisclosureGroup(L10n.text("Conditions & execution rules")) { VStack(alignment: .leading, spacing: 14) { textBlock("Conditions", book.conditions); textBlock("Entry", book.entryRules); textBlock("Invalidation", book.invalidationRules); textBlock("Targets", book.targetRules); textBlock("Risk", book.riskRules) }.padding(.top, 14) } }
                }
            }
        }.pagePadding() }.sheet(item: $editor) { draft in PlaybookEditor(initial: draft).environment(store) }
        .confirmationDialog(L10n.text("Delete this setup?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) { Button(L10n.text("Delete setup"), role: .destructive) { if let setup = deleting { do { try store.deleteSetup(setup) } catch { store.report(error) } }; deleting = nil } } message: { Text(L10n.text("Linked trades remain in your journal and become Unassigned. The playbook and its ideal images are deleted.")) }
    }
    private func stat(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(L10n.text(label)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted); Text(value).font(.title3.monospacedDigit()) }.frame(maxWidth: .infinity, alignment: .leading) }
    private func textBlock(_ label: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(L10n.text(label)).font(.caption).foregroundStyle(Palette.muted); Text(text.isEmpty ? L10n.text("Not recorded") : text).font(.callout).textSelection(.enabled) } }
}
struct PlaybookEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: PlaybookDraft
    @State private var error: String?
    init(initial: PlaybookDraft) { _draft = State(initialValue: initial) }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(L10n.text("Setup playbook")).font(.title2); Spacer(); Button(L10n.text("Cancel")) { dismiss() }; Button(L10n.text("Save setup"), action: save).buttonStyle(.borderedProminent) }.padding(24)
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                TextField(L10n.text("Setup name"), text: $draft.name).font(.title2).textFieldStyle(.roundedBorder)
                TextField(L10n.text("Brief description"), text: $draft.summary).textFieldStyle(.roundedBorder)
                NoteField(title: "Conditions", text: $draft.conditions); NoteField(title: "Entry rules", text: $draft.entry); NoteField(title: "Invalidation rules", text: $draft.invalidation); NoteField(title: "Target rules", text: $draft.target); NoteField(title: "Risk rules", text: $draft.risk)
                Panel(title: "IDEAL EXAMPLES") { ScreenshotAttachmentEditor(shots: $draft.images) }
                if let error { Text(L10n.text(error)).foregroundStyle(Palette.amber) }
            }.padding(24) }
        }.frame(width: 800, height: 790).background(Palette.canvas)
    }
    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { error = "Give this setup a name."; return }
        guard !store.setups.contains(where: { $0.id != draft.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { error = "A setup with this name already exists."; return }
        do {
            try store.commit {
                let setup = store.setups.first { $0.id == draft.id } ?? Setup(id: draft.id, name: name); store.context.insert(setup); setup.name = name; setup.summary = draft.summary
                let p = setup.playbook ?? Playbook(); store.context.insert(p); setup.playbook = p
                p.conditions = draft.conditions; p.entryRules = draft.entry; p.invalidationRules = draft.invalidation; p.targetRules = draft.target; p.riskRules = draft.risk; p.idealImagesData = try JSONEncoder().encode(draft.images)
                for trade in store.trades where trade.setupID == setup.id { var changed = trade; changed.setupName = name; try store.upsert(changed) }
            }; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
