import Foundation
import SwiftData
import Observation

struct JournalError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
@MainActor @Observable final class JournalStore {
    let container: ModelContainer
    let context: ModelContext
    let isDemo: Bool
    private(set) var trades: [TradeRecord] = []
    private(set) var setups: [Setup] = []
    private(set) var instruments: [Instrument] = []
    private(set) var customRules: [CustomRule] = []
    private(set) var reviews: [Review] = []
    private(set) var revision = 0
    var preferences: JournalPreferences
    var errorMessage: String?
    private var models: [UUID: Trade] = [:]
    private let persistsPreferences: Bool
    static let schema = Schema(versionedSchema: JournalSchemaV1.self)
    init(demo: Bool, storageURL: URL? = nil) throws {
        isDemo = demo
        persistsPreferences = !demo && storageURL == nil
        if storageURL == nil, let data = UserDefaults.standard.data(forKey: "journal.preferences"), let saved = try? JSONDecoder().decode(JournalPreferences.self, from: data) { preferences = saved } else { preferences = JournalPreferences() }
        let configuration: ModelConfiguration
        if demo { configuration = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        else {
            let url = try storageURL ?? Self.defaultStoreURL()
            configuration = ModelConfiguration(schema: Self.schema, url: url, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: Self.schema, migrationPlan: JournalMigrationPlan.self, configurations: configuration)
        context = ModelContext(container); context.autosaveEnabled = false
        try refresh()
        if instruments.isEmpty {
            for symbol in Catalog.instruments { context.insert(Instrument(symbol: symbol)) }
            try context.save(); try refresh()
        }
        if demo { try DemoData.populate(self) }
    }
    static func defaultStoreURL() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("LiquidityEdge", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Journal.store")
    }
    func refresh() throws {
        let fetched = try context.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let decoded = try fetched.map { try $0.record() }
        models = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) }); trades = decoded
        setups = try context.fetch(FetchDescriptor<Setup>(sortBy: [SortDescriptor(\.name)]))
        instruments = try context.fetch(FetchDescriptor<Instrument>(sortBy: [SortDescriptor(\.symbol)]))
        customRules = try context.fetch(FetchDescriptor<CustomRule>(sortBy: [SortDescriptor(\.name)]))
        reviews = try context.fetch(FetchDescriptor<Review>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        revision += 1
    }
    func model(_ id: UUID) -> Trade? { models[id] }
    func commit(_ operation: () throws -> Void) throws {
        do { try operation(); try context.save(); try refresh() }
        catch { context.rollback(); try? refresh(); throw error }
    }
    func save(_ record: TradeRecord, screenshots: [ScreenshotDraft]) throws {
        if let error = record.validationError { throw JournalError(message: error) }
        try commit {
            let model = try upsert(record)
            let retained = Set(screenshots.map(\.id))
            for shot in model.screenshots where !retained.contains(shot.id) { context.delete(shot) }
            for shot in screenshots {
                if let existing = model.screenshots.first(where: { $0.id == shot.id }) {
                    existing.category = shot.category; existing.annotationData = try JSONEncoder().encode(shot.annotations)
                } else {
                    let image = TradeScreenshot(id: shot.id, name: shot.name, category: shot.category, imageData: shot.imageData, thumbnailData: shot.thumbnailData, annotationData: try JSONEncoder().encode(shot.annotations))
                    context.insert(image); image.trade = model
                }
            }
        }
    }
    @discardableResult func upsert(_ record: TradeRecord) throws -> Trade {
        let model: Trade
        if let existing = models[record.id] { model = existing; try model.update(record) }
        else { model = try Trade(record: record); context.insert(model); models[record.id] = model }
        model.setup = setups.first { $0.id == record.setupID }
        for violation in model.violations { context.delete(violation) }
        for name in Set(record.brokenRules) { let violation = RuleViolation(name: name); context.insert(violation); violation.trade = model }
        let tags = try context.fetch(FetchDescriptor<TradeTag>())
        model.tags = Array(Set(record.tags)).sorted().map { name in
            if let existing = tags.first(where: { $0.name == name }) { return existing }
            let tag = TradeTag(name: name); context.insert(tag); return tag
        }
        return model
    }
    func deleteTrade(_ id: UUID) throws { guard let trade = models[id] else { return }; try commit { context.delete(trade) } }
    func deleteSetup(_ setup: Setup) throws {
        try commit {
            for trade in trades where trade.setupID == setup.id { var changed = trade; changed.setupID = nil; changed.setupName = "Unassigned"; try upsert(changed) }
            context.delete(setup)
        }
    }
    func savePreferences() throws {
        guard preferences.accountSize > 0, preferences.accountSize.isFinite, preferences.defaultRiskPercent >= 0, preferences.defaultRiskPercent <= 100, TimeZone(identifier: preferences.timezone) != nil, preferences.currency.count == 3 else { throw JournalError(message: "Check account size, risk percentage, three-letter currency and time zone.") }
        if persistsPreferences { UserDefaults.standard.set(try JSONEncoder().encode(preferences), forKey: "journal.preferences") }
        revision += 1
    }
    func report(_ error: Error) { errorMessage = error.localizedDescription }
}
