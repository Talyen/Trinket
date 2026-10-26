import Foundation
import TrinketContent
import TrinketCore

/// Lossless changes to a recorded snapshot, before content repair or merge.
/// Gold and roster edits do not copy the inventory or spatial maps into the outbox.
struct CloudSaveSnapshotDelta: Codable, Equatable, Sendable {
    enum Change: Codable, Equatable, Sendable {
        case schemaVersion(Int)
        case modifiedAt(Date)
        case worldSeed(UInt64)
        case starterSelection(StarterSelectionState)
        case journey(JourneyProgressState)
        case activeHero(String)
        case activeCompanion(String)
        case unlockedHeroes(Set<String>)
        case unlockedCompanions(Set<String>)
        case abilities([String: RosterHydration.AbilityLoadoutIDs])
        case progressions([String: CombatantProgression])
        case equipment([String: [String: String]])
        case talents([String: Set<String>])
        case gold(Int)
        case inventory([StoredInventoryItem])
        case homestead(PlayerHomesteadState)
        case spires(PlayerSpiresState)
        case labyrinth(PlayerLabyrinthState)
        case voyage(Data?)
        case library(PlayerLibraryState?)
        case contracts(PlayerContractsState)
        case corruptionCooldown(Int)
    }

    let changes: [Change]

    init(from before: CloudSaveSnapshot, to after: CloudSaveSnapshot) {
        var changes: [Change] = []
        func record<Value: Equatable>(_ field: KeyPath<CloudSaveSnapshot, Value>, as change: (Value) -> Change) {
            let value = after[keyPath: field]
            if before[keyPath: field] != value {
                changes.append(change(value))
            }
        }
        // Keep the historical roster-first order and the existing encoded cases.
        // Optional values, including nil, are recorded without content repair.
        record(\.roster.activeHeroID, as: Change.activeHero)
        record(\.roster.activeCompanionID, as: Change.activeCompanion)
        record(\.roster.unlockedHeroIDs, as: Change.unlockedHeroes)
        record(\.roster.unlockedCompanionIDs, as: Change.unlockedCompanions)
        record(\.roster.abilityLoadouts, as: Change.abilities)
        record(\.roster.progressions, as: Change.progressions)
        record(\.roster.equipment, as: Change.equipment)
        record(\.roster.unlockedTalents, as: Change.talents)
        record(\.roster.gold, as: Change.gold)
        record(\.schemaVersion, as: Change.schemaVersion)
        record(\.modifiedAt, as: Change.modifiedAt)
        record(\.worldSeed, as: Change.worldSeed)
        record(\.starterSelection, as: Change.starterSelection)
        record(\.journey, as: Change.journey)
        record(\.inventory, as: Change.inventory)
        record(\.homestead, as: Change.homestead)
        record(\.spires, as: Change.spires)
        record(\.labyrinth, as: Change.labyrinth)
        record(\.library, as: Change.library)
        record(\.voyagePayload, as: Change.voyage)
        record(\.contracts, as: Change.contracts)
        record(\.corruptionAltarCooldownRemaining, as: Change.corruptionCooldown)
        self.changes = changes
    }

    func applying(to original: CloudSaveSnapshot) -> CloudSaveSnapshot {
        var snapshot = original
        for change in changes {
            switch change {
            case let .schemaVersion(value): snapshot.schemaVersion = value
            case let .modifiedAt(value): snapshot.modifiedAt = value
            case let .worldSeed(value): snapshot.worldSeed = value
            case let .starterSelection(value): snapshot.starterSelection = value
            case let .journey(value): snapshot.journey = value
            case let .activeHero(value): snapshot.roster.activeHeroID = value
            case let .activeCompanion(value): snapshot.roster.activeCompanionID = value
            case let .unlockedHeroes(value): snapshot.roster.unlockedHeroIDs = value
            case let .unlockedCompanions(value): snapshot.roster.unlockedCompanionIDs = value
            case let .abilities(value): snapshot.roster.abilityLoadouts = value
            case let .progressions(value): snapshot.roster.progressions = value
            case let .equipment(value): snapshot.roster.equipment = value
            case let .talents(value): snapshot.roster.unlockedTalents = value
            case let .gold(value): snapshot.roster.gold = value
            case let .inventory(value): snapshot.inventory = value
            case let .homestead(value): snapshot.homestead = value
            case let .spires(value): snapshot.spires = value
            case let .labyrinth(value): snapshot.labyrinth = value
            case let .library(value): snapshot.library = value
            case let .voyage(value): snapshot.voyagePayload = value
            case let .contracts(value): snapshot.contracts = value
            case let .corruptionCooldown(value): snapshot.corruptionAltarCooldownRemaining = value
            }
        }
        return snapshot
    }
}
