enum StageCompletion {
    static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        pet: Combatant,
        roster: inout PlayerRosterState,
        inventory: inout PlayerInventoryState,
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        guard !journey.hasClaimedRewards(for: stage) else { return }

        roster.grantGold(stage.rewards.gold)
        roster.grantExperience(stage.rewards.experience, to: hero)
        roster.grantExperience(stage.rewards.experience, to: pet)

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
        in chapters: [Chapter],
        roster: inout PlayerRosterState,
        inventory: inout PlayerInventoryState,
        journey: inout JourneyProgressState,
        resolveTemplate: (String) -> InventoryItem? = GameContent.itemTemplate(matching:)
    ) {
        claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            pet: pet,
            roster: &roster,
            inventory: &inventory,
            journey: &journey,
            resolveTemplate: resolveTemplate
        )
        journey.complete(stage, in: chapters)
    }
}
