import Foundation
import SwiftData

@Model final class Trade {
    @Attribute(.unique) var id: UUID
    var date: Date
    var recordData: Data
    var setup: Setup?
    @Relationship(deleteRule: .cascade, inverse: \TradeScreenshot.trade) var screenshots: [TradeScreenshot] = []
    @Relationship(deleteRule: .cascade, inverse: \RuleViolation.trade) var violations: [RuleViolation] = []
    @Relationship(inverse: \TradeTag.trades) var tags: [TradeTag] = []
    init(record: TradeRecord) throws { id = record.id; date = record.date; recordData = try JSONEncoder().encode(record) }
    func record() throws -> TradeRecord { try JSONDecoder().decode(TradeRecord.self, from: recordData) }
    func update(_ record: TradeRecord) throws { date = record.date; recordData = try JSONEncoder().encode(record) }
}
@Model final class TradeScreenshot {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    @Attribute(.externalStorage) var imageData: Data
    var thumbnailData: Data
    var annotationData: Data
    var trade: Trade?
    init(id: UUID = UUID(), name: String, category: String, imageData: Data, thumbnailData: Data, annotationData: Data = Data()) {
        self.id = id; self.name = name; self.category = category; self.imageData = imageData; self.thumbnailData = thumbnailData; self.annotationData = annotationData
    }
}
@Model final class TradeTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var trades: [Trade] = []
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}
@Model final class Setup {
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String
    @Relationship(inverse: \Trade.setup) var trades: [Trade] = []
    @Relationship(deleteRule: .cascade, inverse: \Playbook.setup) var playbook: Playbook?
    init(id: UUID = UUID(), name: String, summary: String = "") { self.id = id; self.name = name; self.summary = summary }
}
@Model final class Playbook {
    @Attribute(.unique) var id: UUID
    var conditions = ""
    var entryRules = ""
    var invalidationRules = ""
    var targetRules = ""
    var riskRules = ""
    @Attribute(.externalStorage) var idealImagesData: Data = Data()
    var setup: Setup?
    init(id: UUID = UUID()) { self.id = id }
}
@Model final class Review {
    @Attribute(.unique) var id: UUID
    var period: String
    var date: Date
    var worked = ""
    var didNot = ""
    var repeatNext = ""
    var stop = ""
    var adjustment = ""
    init(id: UUID = UUID(), period: String, date: Date) { self.id = id; self.period = period; self.date = date }
}
@Model final class RuleViolation {
    @Attribute(.unique) var id: UUID
    var name: String
    var trade: Trade?
    init(name: String) { id = UUID(); self.name = name }
}
@Model final class Instrument {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var enabled: Bool
    init(id: UUID = UUID(), symbol: String, enabled: Bool = true) { self.id = id; self.symbol = symbol; self.enabled = enabled }
}
@Model final class CustomRule {
    @Attribute(.unique) var id: UUID
    var name: String
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}
