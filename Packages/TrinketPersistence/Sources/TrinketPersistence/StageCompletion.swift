import Foundation
import TrinketCore
import TrinketContent

public struct StageCompletionContext: Sendable {
    public var roster: PlayerRosterState
    public var inventory: PlayerInventoryState
    public var homestead: PlayerHomesteadState
    public var journey: JourneyProgressState

    public init(
        roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        homestead: PlayerHomesteadState,
        journey: JourneyProgressState
    ) {
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
        self.journey = journey
    }

    public mutating func apply(to save: inout PlayerSave) {
        save.roster = SavedRosterState(roster)
        save.inventory = SavedInventoryState(inventory)
        save.homestead = SavedHomesteadState(homestead)
        save.journey = journey
    }
}

public enum StageCompletion {
    public static func complete(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        in chapters: [Chapter],
        context: inout StageCompletionContext,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            enemyEncounterLevel: resolvedEncounterLevel(for: stage, in: chapters),
            context: &context,
            resolveTemplate: resolveTemplate
        )
        if !context.journey.isCompleted(stage) {
            context.journey.complete(stage, in: chapters)
        }
    }

    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        enemyEncounterLevel: Int? = nil,
        context: inout StageCompletionContext,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        guard !context.journey.hasClaimedRewards(for: stage) else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? resolvedEncounterLevel(for: stage, in: GameContent.chapters)

        context.roster.grantGold(stage.rewards.gold + battleEarnedGold)
        if case .battle = stage.encounter {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &context.roster)
            grantBattleExperience(enemyLevel: encounterLevel, to: pet, roster: &context.roster)
        }
        context.homestead.grant(context.homestead.adjustedMaterialRewards(stage.rewards.materialRewards))

        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = resolveTemplate(templateID) else { continue }
            context.inventory.addRewardItem(from: template, for: stage)
        }

        context.journey.markRewardsClaimed(for: stage)
    }

    /// Whether `context` already reflects the rewards that `baseline` would gain from `stage`.
    public static func rewardsReflected(
        for stage: Stage,
        baseline: StageCompletionContext,
        in context: StageCompletionContext,
        hero: Combatant,
        pet: Combatant,
        in chapters: [Chapter] = GameContent.chapters
    ) -> Bool {
        for templateID in stage.rewards.itemTemplateIDs {
            let itemID = "\(stage.id)-\(templateID)"
            if context.inventory.item(matching: itemID) == nil {
                return false
            }
        }

        let expectedMinGold = baseline.roster.gold + stage.rewards.gold
        if context.roster.gold < expectedMinGold {
            return false
        }

        for reward in context.homestead.adjustedMaterialRewards(stage.rewards.materialRewards) {
            let baselineQuantity = baseline.homestead.resources[reward.resource, default: 0]
            if context.homestead.resources[reward.resource, default: 0] < baselineQuantity + reward.quantity {
                return false
            }
        }

        guard case .battle = stage.encounter else { return true }

        let encounterLevel = resolvedEncounterLevel(for: stage, in: chapters)
        let heroAward = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: baseline.roster.progression(for: hero).level,
            enemyLevel: encounterLevel,
            highestLevel: baseline.roster.highestHeroLevel
        )
        if !experienceAwardReflected(
            baseline: baseline.roster.progression(for: hero),
            current: context.roster.progression(for: hero),
            award: heroAward
        ) {
            return false
        }

        let petAward = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: baseline.roster.progression(for: pet).level,
            enemyLevel: encounterLevel,
            highestLevel: baseline.roster.highestPetLevel
        )
        return experienceAwardReflected(
            baseline: baseline.roster.progression(for: pet),
            current: context.roster.progression(for: pet),
            award: petAward
        )
    }

    private static func experienceAwardReflected(
        baseline: CombatantProgression,
        current: CombatantProgression,
        award: Int
    ) -> Bool {
        if award == 0 { return true }
        if current.level > baseline.level { return true }
        if current.level == baseline.level, current.currentXP >= baseline.currentXP + award {
            return true
        }
        return false
    }

    private static func resolvedEncounterLevel(for stage: Stage, in chapters: [Chapter]) -> Int {
        guard let chapter = chapters.first(where: { $0.id == stage.chapterID }) else {
            return 1
        }
        return EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
    }

    private static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestPetLevel
        let award = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
        roster.grantExperience(award, to: combatant)
    }
}
