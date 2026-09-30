import SwiftData

enum JournalSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Trade.self, TradeScreenshot.self, TradeTag.self, Setup.self, Playbook.self, Review.self, RuleViolation.self, Instrument.self, CustomRule.self]
    }
}
enum JournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JournalSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
