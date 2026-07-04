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
}

public enum StageCompletion {
    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        enemyEncounterLevel: Int? = nil,
        roster: inout PlayerRosterState,
        inventory: inout PlayerInventoryState,
        homestead: inout PlayerHomesteadState,
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        var ctx = StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: homestead,
            journey: journey
        )
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            enemyEncounterLevel: enemyEncounterLevel,
            context: &ctx,
            resolveTemplate: resolveTemplate
        )
        roster = ctx.roster
        inventory = ctx.inventory
        homestead = ctx.homestead
        journey = ctx.journey
    }

    public static func complete(
        _ stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        in chapters: [Chapter],
        roster: inout PlayerRosterState,
        inventory: inout PlayerInventoryState,
        homestead: inout PlayerHomesteadState,
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        var ctx = StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: homestead,
            journey: journey
        )
        complete(
            stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            in: chapters,
            context: &ctx,
            resolveTemplate: resolveTemplate
        )
        roster = ctx.roster
        inventory = ctx.inventory
        homestead = ctx.homestead
        journey = ctx.journey
    }

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
        guard !context.journey.hasClaimedRewards(for: stage) else { return }

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
        let award = ExperienceScaling.battleAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel
        )
        roster.grantExperience(award, to: combatant)
    }
}
