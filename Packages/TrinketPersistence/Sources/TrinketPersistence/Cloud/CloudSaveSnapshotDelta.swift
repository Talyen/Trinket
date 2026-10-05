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
        case contracts(PlayerContractsState)
        case corruptionCooldown(Int)
    }

    let changes: [Change]

    init(from before: CloudSaveSnapshot, to after: CloudSaveSnapshot) {
        var changes = Self.rosterChanges(from: before.roster, to: after.roster)
        if before.schemaVersion != after.schemaVersion {
            changes.append(.schemaVersion(after.schemaVersion))
        }
        if before.modifiedAt != after.modifiedAt {
            changes.append(.modifiedAt(after.modifiedAt))
        }
        if before.worldSeed != after.worldSeed {
            changes.append(.worldSeed(after.worldSeed))
        }
        if before.starterSelection != after.starterSelection {
            changes.append(.starterSelection(after.starterSelection))
        }
        if before.journey != after.journey {
            changes.append(.journey(after.journey))
        }
        if before.inventory != after.inventory {
            changes.append(.inventory(after.inventory))
        }
        if before.homestead != after.homestead {
            changes.append(.homestead(after.homestead))
        }
        if before.spires != after.spires {
            changes.append(.spires(after.spires))
        }
        if before.labyrinth != after.labyrinth {
            changes.append(.labyrinth(after.labyrinth))
        }
        if before.voyagePayload != after.voyagePayload {
            changes.append(.voyage(after.voyagePayload))
        }
        if before.contracts != after.contracts {
            changes.append(.contracts(after.contracts))
        }
        if before.corruptionAltarCooldownRemaining != after.corruptionAltarCooldownRemaining {
            changes.append(.corruptionCooldown(after.corruptionAltarCooldownRemaining))
        }
        self.changes = changes
    }

    private static func rosterChanges(from before: CloudRosterSnapshot, to after: CloudRosterSnapshot) -> [Change] {
        var changes: [Change] = []
        if before.activeHeroID != after.activeHeroID {
            changes.append(.activeHero(after.activeHeroID))
        }
        if before.activeCompanionID != after.activeCompanionID {
            changes.append(.activeCompanion(after.activeCompanionID))
        }
        if before.unlockedHeroIDs != after.unlockedHeroIDs {
            changes.append(.unlockedHeroes(after.unlockedHeroIDs))
        }
        if before.unlockedCompanionIDs != after.unlockedCompanionIDs {
            changes.append(.unlockedCompanions(after.unlockedCompanionIDs))
        }
        if before.abilityLoadouts != after.abilityLoadouts {
            changes.append(.abilities(after.abilityLoadouts))
        }
        if before.progressions != after.progressions {
            changes.append(.progressions(after.progressions))
        }
        if before.equipment != after.equipment {
            changes.append(.equipment(after.equipment))
        }
        if before.unlockedTalents != after.unlockedTalents {
            changes.append(.talents(after.unlockedTalents))
        }
        if before.gold != after.gold {
            changes.append(.gold(after.gold))
        }
        return changes
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
            case let .voyage(value): snapshot.voyagePayload = value
            case let .contracts(value): snapshot.contracts = value
            case let .corruptionCooldown(value): snapshot.corruptionAltarCooldownRemaining = value
            }
        }
        return snapshot
    }
}
