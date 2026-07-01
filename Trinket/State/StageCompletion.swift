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
        var homestead = PlayerHomesteadState.freshStart
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            roster: &roster,
            inventory: &inventory,
            homestead: &homestead,
            journey: &journey,
            resolveTemplate: resolveTemplate
        )
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
        guard !journey.hasClaimedRewards(for: stage) else { return }

        roster.grantGold(stage.rewards.gold + battleEarnedGold)
        roster.grantExperience(stage.rewards.experience, to: hero)
        roster.grantExperience(stage.rewards.experience, to: pet)
        homestead.grant(homestead.adjustedMaterialRewards(stage.rewards.materialRewards))

        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = resolveTemplate(templateID) else { continue }
            inventory.addRewardItem(from: template, for: stage)
        }

        journey.markRewardsClaimed(for: stage)
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
        var homestead = PlayerHomesteadState.freshStart
        complete(
            stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            in: chapters,
            roster: &roster,
            inventory: &inventory,
            homestead: &homestead,
            journey: &journey,
            resolveTemplate: resolveTemplate
        )
    }

    static func complete(
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
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            battleEarnedGold: battleEarnedGold,
            roster: &roster,
            inventory: &inventory,
            homestead: &homestead,
            journey: &journey,
            resolveTemplate: resolveTemplate
        )
        journey.complete(stage, in: chapters)
    }
}
