# LIQUIDITY EDGE — Architecture

Native macOS 14+, SwiftUI, SwiftData, Swift Charts. No network dependencies.

## Boundaries
- Models: versioned Codable trade records and normalized SwiftData ownership relationships. Trade owns screenshots and violations. Setup owns its Playbook; deleting a setup preserves trades. Tags are reusable.
- Services: a main-actor JournalStore owns explicit save/rollback operations and a cached value snapshot for UI analytics. Persistent storage is in Application Support. Demo has an entirely separate in-memory container.
- Utilities: pure, Foundation-only analytics and search; no dependency on SwiftUI or persistence. Metrics are calculated on closed, net-of-fees trades. Manual R is authoritative; gross PnL minus fees is net PnL. Missing R is excluded from R denominators.
- ViewModels: edit drafts are value types. Cancel never mutates a saved model. Validation runs before saving.
- Views/Components/Charts: navigation, progressive disclosure editor, filtered analysis, journal, reviews, playbook, image review and settings.
- Backup: versioned JSON includes all records, screenshots, annotations, catalog, reviews and preferences. Restore validates the complete document before merging by stable UUID, then saves atomically. CSV supports portable trade export/import.

## Process before outcome
Compliance requires both the explicit plan flag and no broken rules. A positive invalid trade remains a process warning. Trading concepts are user-labeled observations, never inferred market signals. Missing model validation is not silently treated as a confirmed condition. Sample bands describe sample count, not statistical proof of an edge.

## UI
Graphite canvas, narrow terminal-inspired type hierarchy, SF system fonts, mint only for positive outcomes, amber for invalid execution, restrained borders. Local data badge and demo banner make storage state explicit. Native keyboard shortcuts and sheets. Reduced motion respected.

## Delivery
An Xcode project with shared app/test schemes and no third-party dependencies. Pure calculation tests can also run via Swift Package Manager. Integration tests cover SwiftData, restore and attachments. See README and TESTING.md.
