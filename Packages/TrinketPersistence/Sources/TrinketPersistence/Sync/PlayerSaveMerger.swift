import Foundation
import TrinketContent
import TrinketCore

/// Field-wise merge for divergent local and remote saves.
public enum PlayerSaveMerger {
    public static func merge(_ local: PlayerSave, _ remote: PlayerSave) -> PlayerSave {
        let preferRemote = remote.modifiedAt > local.modifiedAt
        var merged = local.modifiedAt >= remote.modifiedAt ? local : remote
        merged.journey = mergeJourney(local.journey, remote.journey)
        merged.roster = mergeRoster(local.roster, remote.roster, preferRemote: preferRemote)
        merged.inventory = mergeInventory(local.inventory, remote.inventory, preferRemote: preferRemote)
        merged.homestead = mergeHomestead(local.homestead, remote.homestead)
        merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        merged.schemaVersion = PlayerSave.currentSchemaVersion
        return PlayerSaveSanitizer.sanitize(merged)
    }

    private static func mergeJourney(
        _ local: JourneyProgressState,
        _ remote: JourneyProgressState
    ) -> JourneyProgressState {
        var merged = progressLeader(local, remote)
        merged.completedStageIDs = local.completedStageIDs.union(remote.completedStageIDs)
        merged.claimedRewardStageIDs = local.claimedRewardStageIDs.union(remote.claimedRewardStageIDs)
        merged.lastCompletedStageID = preferredLastCompleted(
            local.lastCompletedStageID,
            remote.lastCompletedStageID,
            completed: merged.completedStageIDs
        )
        return merged
    }

    private static func progressLeader(
        _ local: JourneyProgressState,
        _ remote: JourneyProgressState
    ) -> JourneyProgressState {
        if local.completedStageIDs.count != remote.completedStageIDs.count {
            return local.completedStageIDs.count > remote.completedStageIDs.count ? local : remote
        }
        return local
    }

    private static func preferredLastCompleted(
        _ local: String?,
        _ remote: String?,
        completed: Set<String>
    ) -> String? {
        let candidates = [local, remote].compactMap { $0 }.filter { completed.contains($0) }
        return PlayerSaveSanitizer.latestStageID(in: Set(candidates), chapters: GameContent.chapters)
    }

    private static func mergeRoster(
        _ local: SavedRosterState,
        _ remote: SavedRosterState,
        preferRemote: Bool
    ) -> SavedRosterState {
        var merged = local.gold >= remote.gold ? local : remote
        merged.gold = max(local.gold, remote.gold)
        merged.unlockedHeroIDs = Array(Set(local.unlockedHeroIDs).union(remote.unlockedHeroIDs)).sorted()
        merged.unlockedPetIDs = Array(Set(local.unlockedPetIDs).union(remote.unlockedPetIDs)).sorted()
        merged.progressions = mergeProgressions(local.progressions, remote.progressions)
        merged.abilityLoadouts = local.abilityLoadouts.merging(remote.abilityLoadouts) { preferRemote ? $1 : $0 }
        merged.equipmentLoadouts = local.equipmentLoadouts.merging(remote.equipmentLoadouts) { preferRemote ? $1 : $0 }
        if !merged.unlockedHeroIDs.contains(merged.activeHeroID) {
            merged.activeHeroID = merged.unlockedHeroIDs.first ?? PlayerRosterState.starterHeroID
        }
        if !merged.unlockedPetIDs.contains(merged.activePetID) {
            merged.activePetID = merged.unlockedPetIDs.first ?? PlayerRosterState.starterPetID
        }
        return merged
    }

    private static func mergeProgressions(
        _ local: [String: CombatantProgression],
        _ remote: [String: CombatantProgression]
    ) -> [String: CombatantProgression] {
        let ids = Set(local.keys).union(remote.keys)
        var merged: [String: CombatantProgression] = [:]
        for id in ids {
            switch (local[id], remote[id]) {
            case let (localProgression?, remoteProgression?):
                merged[id] = preferredProgression(localProgression, remoteProgression)
            case let (localProgression?, nil):
                merged[id] = localProgression
            case let (nil, remoteProgression?):
                merged[id] = remoteProgression
            case (nil, nil):
                break
            }
        }
        return merged
    }

    private static func preferredProgression(
        _ local: CombatantProgression,
        _ remote: CombatantProgression
    ) -> CombatantProgression {
        if local.level != remote.level {
            return local.level > remote.level ? local : remote
        }
        return local.currentXP >= remote.currentXP ? local : remote
    }

    private static func mergeInventory(
        _ local: SavedInventoryState,
        _ remote: SavedInventoryState,
        preferRemote: Bool
    ) -> SavedInventoryState {
        var itemsByID: [String: SavedInventoryItem] = [:]
        if preferRemote {
            for item in local.items {
                itemsByID[item.id] = item
            }
            for item in remote.items {
                itemsByID[item.id] = item
            }
        } else {
            for item in remote.items {
                itemsByID[item.id] = item
            }
            for item in local.items {
                itemsByID[item.id] = item
            }
        }
        var merged = local
        merged.items = Array(itemsByID.values)
        return merged
    }

    private static func mergeHomestead(
        _ local: SavedHomesteadState,
        _ remote: SavedHomesteadState
    ) -> SavedHomesteadState {
        var merged = local
        for (resource, quantity) in remote.resources {
            merged.resources[resource] = max(merged.resources[resource, default: 0], quantity)
        }
        for (nodeID, tier) in remote.nodeTiers {
            merged.nodeTiers[nodeID] = max(merged.nodeTiers[nodeID, default: 0], tier)
        }
        return merged
    }
}
