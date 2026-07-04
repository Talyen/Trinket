import Foundation
import TrinketContent
import TrinketCore

/// Field-wise merge for divergent local and remote saves.
public enum PlayerSaveMerger {
    public static func merge(_ local: PlayerSave, _ remote: PlayerSave) -> PlayerSave {
        var merged = local.modifiedAt >= remote.modifiedAt ? local : remote
        merged.journey = mergeJourney(local.journey, remote.journey)
        merged.roster = mergeRoster(local.roster, remote.roster)
        merged.inventory = mergeInventory(local.inventory, remote.inventory)
        merged.homestead = mergeHomestead(local.homestead, remote.homestead)
        merged = reconcileMissingStageRewards(local: local, remote: remote, merged: merged)
        merged.journey.claimedRewardStageIDs = local.journey.claimedRewardStageIDs
            .union(remote.journey.claimedRewardStageIDs)
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

    private static func mergeRoster(_ local: SavedRosterState, _ remote: SavedRosterState) -> SavedRosterState {
        var merged = local.gold >= remote.gold ? local : remote
        merged.gold = max(local.gold, remote.gold)
        merged.unlockedHeroIDs = Array(Set(local.unlockedHeroIDs).union(remote.unlockedHeroIDs)).sorted()
        merged.unlockedPetIDs = Array(Set(local.unlockedPetIDs).union(remote.unlockedPetIDs)).sorted()
        merged.progressions = mergeProgressions(local.progressions, remote.progressions)
        merged.abilityLoadouts = local.abilityLoadouts.merging(remote.abilityLoadouts) { current, _ in current }
        merged.equipmentLoadouts = local.equipmentLoadouts.merging(remote.equipmentLoadouts) { current, _ in current }
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
        _ remote: SavedInventoryState
    ) -> SavedInventoryState {
        var itemsByID: [String: SavedInventoryItem] = [:]
        for item in remote.items {
            itemsByID[item.id] = item
        }
        for item in local.items {
            itemsByID[item.id] = item
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

    private static func reconcileMissingStageRewards(
        local: PlayerSave,
        remote: PlayerSave,
        merged: PlayerSave
    ) -> PlayerSave {
        let remoteOnlyClaimed = remote.journey.claimedRewardStageIDs
            .subtracting(local.journey.claimedRewardStageIDs)
        guard !remoteOnlyClaimed.isEmpty else { return merged }

        var updated = merged
        var roster = merged.playerRoster(inventoryItemIDs: Set(merged.inventory.items.map(\.id)))
        var inventory = merged.inventory.inventory()
        var homestead = merged.homestead.homestead()
        var journey = merged.journey

        let hero = activeHero(for: roster)
        let pet = activePet(for: roster)

        for stageID in remoteOnlyClaimed.sorted() {
            guard let stage = stage(for: stageID) else { continue }
            if stageRewardsPresent(
                for: stage,
                local: local,
                mergedRoster: roster,
                mergedInventory: inventory,
                mergedHomestead: homestead
            ) {
                journey.markRewardsClaimed(for: stage)
                continue
            }

            var context = StageCompletionContext(
                roster: roster,
                inventory: inventory,
                homestead: homestead,
                journey: journey
            )
            StageCompletion.claimRewardsIfNeeded(
                for: stage,
                hero: hero,
                pet: pet,
                context: &context
            )
            roster = context.roster
            inventory = context.inventory
            homestead = context.homestead
            journey = context.journey
        }

        updated.roster = SavedRosterState(roster)
        updated.inventory = SavedInventoryState(inventory)
        updated.homestead = SavedHomesteadState(homestead)
        updated.journey = journey
        return updated
    }

    private static func stageRewardsPresent(
        for stage: Stage,
        local: PlayerSave,
        mergedRoster: PlayerRosterState,
        mergedInventory: PlayerInventoryState,
        mergedHomestead: PlayerHomesteadState
    ) -> Bool {
        let localRoster = local.playerRoster(inventoryItemIDs: Set(local.inventory.items.map(\.id)))
        let localHomestead = local.homestead.homestead()

        for templateID in stage.rewards.itemTemplateIDs {
            let itemID = "\(stage.id)-\(templateID)"
            if mergedInventory.item(matching: itemID) == nil {
                return false
            }
        }

        let expectedMinGold = localRoster.gold + stage.rewards.gold
        if mergedRoster.gold < expectedMinGold {
            return false
        }

        for reward in stage.rewards.materialRewards {
            let localQuantity = localHomestead.resources[reward.resource, default: 0]
            if mergedHomestead.resources[reward.resource, default: 0] < localQuantity + reward.quantity {
                return false
            }
        }

        guard case .battle = stage.encounter else { return true }

        let hero = activeHero(for: mergedRoster)
        let pet = activePet(for: mergedRoster)
        let chapter = GameContent.chapters.first { $0.id == stage.chapterID } ?? GameContent.chapters[0]
        let encounterLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)

        let heroAward = ExperienceScaling.battleAward(
            playerLevel: localRoster.progression(for: hero).level,
            enemyLevel: encounterLevel
        )
        if !experienceAwardReflected(
            local: localRoster.progression(for: hero),
            merged: mergedRoster.progression(for: hero),
            award: heroAward
        ) {
            return false
        }

        let petAward = ExperienceScaling.battleAward(
            playerLevel: localRoster.progression(for: pet).level,
            enemyLevel: encounterLevel
        )
        if !experienceAwardReflected(
            local: localRoster.progression(for: pet),
            merged: mergedRoster.progression(for: pet),
            award: petAward
        ) {
            return false
        }

        return true
    }

    private static func experienceAwardReflected(
        local: CombatantProgression,
        merged: CombatantProgression,
        award: Int
    ) -> Bool {
        if award == 0 { return true }
        if merged.level > local.level { return true }
        if merged.level == local.level, merged.currentXP >= local.currentXP + award {
            return true
        }
        return false
    }

    private static func stage(for id: String) -> Stage? {
        for chapter in GameContent.chapters {
            if let stage = chapter.stages.first(where: { $0.id == id }) {
                return stage
            }
        }
        return nil
    }

    private static func activeHero(for roster: PlayerRosterState) -> Combatant {
        GameContent.heroes.first { $0.id == roster.activeHeroID } ?? GameContent.heroes[0]
    }

    private static func activePet(for roster: PlayerRosterState) -> Combatant {
        GameContent.pets.first { $0.id == roster.activePetID } ?? GameContent.pets[0]
    }
}
