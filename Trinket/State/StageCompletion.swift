struct StageCompletionContext {
    var roster: PlayerRosterState
    var inventory: PlayerInventoryState
    var homestead: PlayerHomesteadState
    var journey: JourneyProgressState
}

enum StageCompletion {
    static func claimRewardsIfNeeded(
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

    static func claimRewardsIfNeeded(
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

    static func complete(
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

    static func complete(
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

    // MARK: - Context-based overloads

    static func claimRewardsIfNeeded(
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
