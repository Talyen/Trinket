import Foundation
import TrinketContent
import TrinketCore

enum StageRewardReconciler {
    static func reconcileMissingStageRewards(
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

        let heroLevel = localRoster.progression(for: hero).level
        let heroCatchUp = ExperienceScaling.catchUpMultiplier(
            for: heroLevel,
            highestLevel: localRoster.highestHeroLevel
        )
        let heroBaseAward = ExperienceScaling.battleAward(
            playerLevel: heroLevel,
            enemyLevel: encounterLevel
        )
        let heroAward = max(1, Int((Double(heroBaseAward) * heroCatchUp).rounded()))
        if !experienceAwardReflected(
            local: localRoster.progression(for: hero),
            merged: mergedRoster.progression(for: hero),
            award: heroAward
        ) {
            return false
        }

        let petLevel = localRoster.progression(for: pet).level
        let petCatchUp = ExperienceScaling.catchUpMultiplier(
            for: petLevel,
            highestLevel: localRoster.highestPetLevel
        )
        let petBaseAward = ExperienceScaling.battleAward(
            playerLevel: petLevel,
            enemyLevel: encounterLevel
        )
        let petAward = max(1, Int((Double(petBaseAward) * petCatchUp).rounded()))
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
