import Foundation
import BattleEngine
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
        roster: inout PlayerRosterState,
        inventory: inout PlayerInventoryState,
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        var ctx = StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: .freshStart,
            journey: journey
        )
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            context: &ctx,
            resolveTemplate: resolveTemplate
        )
        roster = ctx.roster
        inventory = ctx.inventory
        journey = ctx.journey
    }

    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
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
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        var ctx = StageCompletionContext(
            roster: roster,
            inventory: inventory,
            homestead: .freshStart,
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
            context: &context,
            resolveTemplate: resolveTemplate
        )
        context.journey.complete(stage, in: chapters)
    }

    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        pet: Combatant,
        battleEarnedGold: Int = 0,
        context: inout StageCompletionContext,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        guard !context.journey.hasClaimedRewards(for: stage) else { return }

        context.roster.grantGold(stage.rewards.gold + battleEarnedGold)
        context.roster.grantExperience(stage.rewards.experience, to: hero)
        context.roster.grantExperience(stage.rewards.experience, to: pet)
        context.homestead.grant(context.homestead.adjustedMaterialRewards(stage.rewards.materialRewards))

        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = resolveTemplate(templateID) else { continue }
            context.inventory.addRewardItem(from: template, for: stage)
        }

        context.journey.markRewardsClaimed(for: stage)
    }
}
