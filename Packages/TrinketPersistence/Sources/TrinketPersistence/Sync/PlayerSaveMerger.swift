import Foundation
import TrinketContent
import TrinketCore

public enum PlayerSaveReconcileOutcome: Equatable {
    case keepLocal
    case applyRemote(PlayerSave)
    case uploadLocal
    case applyMerged(PlayerSave)
}

/// Field-wise merge and session-start reconcile for divergent local and remote saves.
public enum PlayerSaveMerger {
    public static func reconcile(local: PlayerSave?, remote: RemotePlayerSave?) -> PlayerSaveReconcileOutcome {
        switch (local, remote) {
        case let (local?, nil):
            return .uploadLocal
        case let (nil, remote?):
            return .applyRemote(remote.save)
        case let (local?, remote?):
            return reconcileBoth(local: local, remote: remote)
        case (nil, nil):
            return .keepLocal
        }
    }

    public static func pickAuthoritative(local: PlayerSave, remote: PlayerSave) -> PlayerSave {
        if local.sessionGeneration != remote.sessionGeneration {
            return local.sessionGeneration < remote.sessionGeneration ? remote : local
        }
        return merge(local, remote)
    }

    public static func merge(_ local: PlayerSave, _ remote: PlayerSave) -> PlayerSave {
        let preferRemote = remote.modifiedAt > local.modifiedAt
        let sameTimestamp = local.modifiedAt == remote.modifiedAt
        var merged = local.modifiedAt >= remote.modifiedAt ? local : remote
        merged.journey = mergeJourney(local.journey, remote.journey)
        merged.roster = mergeRoster(
            local.roster,
            remote.roster,
            preferRemote: preferRemote,
            sameTimestamp: sameTimestamp
        )
        merged.inventory = mergeInventory(local.inventory, remote.inventory, preferRemote: preferRemote)
        merged.homestead = mergeHomestead(
            local.homestead,
            remote.homestead,
            preferRemote: preferRemote,
            sameTimestamp: sameTimestamp
        )
        merged = reconcileMissingStageRewards(local: local, remote: remote, merged: merged)
        merged.journey.claimedRewardStageIDs = local.journey.claimedRewardStageIDs
            .union(remote.journey.claimedRewardStageIDs)
        merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
        merged.schemaVersion = PlayerSave.currentSchemaVersion
        return PlayerSaveSanitizer.sanitize(merged)
    }

    private static func reconcileBoth(local: PlayerSave, remote: RemotePlayerSave) -> PlayerSaveReconcileOutcome {
        if local.sessionGeneration != remote.save.sessionGeneration {
            return local.sessionGeneration < remote.save.sessionGeneration
                ? .applyRemote(remote.save)
                : .uploadLocal
        }

        if local == remote.save {
            return .keepLocal
        }

        let merged = merge(local, remote.save)
        if merged == local {
            return merged == remote.save ? .keepLocal : .uploadLocal
        }
        if merged == remote.save {
            return .applyRemote(remote.save)
        }
        return .applyMerged(merged)
    }

    private static func reconcileMissingStageRewards(
        local: PlayerSave,
        remote: PlayerSave,
        merged: PlayerSave
    ) -> PlayerSave {
        let remoteOnlyClaimed = remote.journey.claimedRewardStageIDs
            .subtracting(local.journey.claimedRewardStageIDs)
        guard !remoteOnlyClaimed.isEmpty else { return merged }

        let baseline = local.stageCompletionContext()
        var context = merged.stageCompletionContext()
        let hero = activeCombatant(for: context.roster.activeHeroID, in: GameContent.heroes, fallback: GameContent.heroes[0])
        let pet = activeCombatant(for: context.roster.activePetID, in: GameContent.pets, fallback: GameContent.pets[0])

        for stageID in remoteOnlyClaimed.sorted() {
            guard let stage = GameContent.stage(id: stageID) else { continue }
            if StageCompletion.rewardsReflected(
                for: stage,
                baseline: baseline,
                in: context,
                hero: hero,
                pet: pet
            ) {
                if !context.journey.isCompleted(stage) {
                    context.journey.complete(stage, in: GameContent.chapters)
                }
                context.journey.markRewardsClaimed(for: stage)
                continue
            }

            StageCompletion.complete(
                stage,
                hero: hero,
                pet: pet,
                in: GameContent.chapters,
                context: &context
            )
        }

        var updated = merged
        context.apply(to: &updated)
        return updated
    }

    private static func activeCombatant(
        for id: String,
        in catalog: [Combatant],
        fallback: Combatant
    ) -> Combatant {
        catalog.first { $0.id == id } ?? fallback
    }

    private static func mergeJourney(
        _ local: JourneyProgressState,
        _ remote: JourneyProgressState
    ) -> JourneyProgressState {
        var merged = progressLeader(local, remote)
        merged.completedStageIDs = local.completedStageIDs.union(remote.completedStageIDs)
        merged.claimedRewardStageIDs = local.claimedRewardStageIDs
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

    private static func mergeSpendableCounter(
        local: Int,
        remote: Int,
        preferRemote: Bool,
        sameTimestamp: Bool
    ) -> Int {
        if sameTimestamp {
            return max(local, remote)
        }
        return preferRemote ? remote : local
    }

    private static func mergeRoster(
        _ local: SavedRosterState,
        _ remote: SavedRosterState,
        preferRemote: Bool,
        sameTimestamp: Bool
    ) -> SavedRosterState {
        var merged = preferRemote ? remote : local
        merged.gold = mergeSpendableCounter(
            local: local.gold,
            remote: remote.gold,
            preferRemote: preferRemote,
            sameTimestamp: sameTimestamp
        )
        merged.unlockedHeroIDs = Array(Set(local.unlockedHeroIDs).union(remote.unlockedHeroIDs)).sorted()
        merged.unlockedPetIDs = Array(Set(local.unlockedPetIDs).union(remote.unlockedPetIDs)).sorted()
        merged.progressions = mergeProgressions(local.progressions, remote.progressions)
        merged.abilityLoadouts = mergeAbilityLoadouts(
            local.abilityLoadouts,
            remote.abilityLoadouts,
            preferRemote: preferRemote
        )
        merged.equipmentLoadouts = mergeEquipmentLoadouts(
            local.equipmentLoadouts,
            remote.equipmentLoadouts,
            preferRemote: preferRemote
        )
        if !merged.unlockedHeroIDs.contains(merged.activeHeroID) {
            merged.activeHeroID = merged.unlockedHeroIDs.first ?? PlayerRosterState.starterHeroID
        }
        if !merged.unlockedPetIDs.contains(merged.activePetID) {
            merged.activePetID = merged.unlockedPetIDs.first ?? PlayerRosterState.starterPetID
        }
        return merged
    }

    private static func mergeAbilityLoadouts(
        _ local: [String: SavedAbilityLoadout],
        _ remote: [String: SavedAbilityLoadout],
        preferRemote: Bool
    ) -> [String: SavedAbilityLoadout] {
        let ids = Set(local.keys).union(remote.keys)
        var merged: [String: SavedAbilityLoadout] = [:]
        for id in ids {
            switch (local[id], remote[id]) {
            case let (localLoadout?, remoteLoadout?):
                merged[id] = localLoadout.merged(with: remoteLoadout, preferOther: preferRemote)
            case let (localLoadout?, nil):
                merged[id] = localLoadout
            case let (nil, remoteLoadout?):
                merged[id] = remoteLoadout
            case (nil, nil):
                break
            }
        }
        return merged
    }

    private static func mergeEquipmentLoadouts(
        _ local: [String: SavedEquipmentLoadout],
        _ remote: [String: SavedEquipmentLoadout],
        preferRemote: Bool
    ) -> [String: SavedEquipmentLoadout] {
        let ids = Set(local.keys).union(remote.keys)
        var merged: [String: SavedEquipmentLoadout] = [:]
        for id in ids {
            switch (local[id], remote[id]) {
            case let (localLoadout?, remoteLoadout?):
                merged[id] = localLoadout.merged(with: remoteLoadout, preferOther: preferRemote)
            case let (localLoadout?, nil):
                merged[id] = localLoadout
            case let (nil, remoteLoadout?):
                merged[id] = remoteLoadout
            case (nil, nil):
                break
            }
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
        _ remote: SavedHomesteadState,
        preferRemote: Bool,
        sameTimestamp: Bool
    ) -> SavedHomesteadState {
        var merged = preferRemote ? remote : local
        let resourceKeys = Set(local.resources.keys).union(remote.resources.keys)
        for resource in resourceKeys {
            let localQuantity = local.resources[resource, default: 0]
            let remoteQuantity = remote.resources[resource, default: 0]
            merged.resources[resource] = mergeSpendableCounter(
                local: localQuantity,
                remote: remoteQuantity,
                preferRemote: preferRemote,
                sameTimestamp: sameTimestamp
            )
        }
        for (nodeID, tier) in remote.nodeTiers {
            merged.nodeTiers[nodeID] = max(merged.nodeTiers[nodeID, default: 0], tier)
        }
        for (nodeID, tier) in local.nodeTiers {
            merged.nodeTiers[nodeID] = max(merged.nodeTiers[nodeID, default: 0], tier)
        }
        return merged
    }
}
