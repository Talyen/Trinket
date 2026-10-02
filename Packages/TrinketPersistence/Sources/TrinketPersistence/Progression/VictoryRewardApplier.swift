import Foundation
import TrinketContent
import TrinketCore

public enum VictoryRewardApplier {
    public static func isBoss(enemyID: String?) -> Bool {
        guard let enemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }

    /// Campaign adjustment for completion callers without a captured encounter level.
    public static func partyAdjustedEncounterLevel(authoredLevel: Int, save: PlayerSave) -> Int {
        EncounterLevelResolver.campaignAdjusted(
            authoredLevel,
            partyAverageLevel: save.roster.activePartyAverageLevel,
        )
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleGold: BattleGoldFlow,
        goldFoundPercent: Int,
        goldFindFlat: Int = 0,
    ) -> Int {
        BattleRewardPlan(
            stageGold: stageGold, goldFindPercent: goldFoundPercent, goldFindFlat: goldFindFlat,
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        ).resolve(battleGold: battleGold).goldDelta
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleGold: BattleGoldFlow,
        homestead: PlayerHomesteadState,
    ) -> Int {
        BattleRewardPlan(
            stageGold: stageGold, goldFindPercent: homestead.effects.goldFindPercent,
            goldFindFlat: homestead.effects.goldFindFlat,
            initialRewardRemainders: homestead.rewardRemainders ?? .zero,
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        ).resolve(battleGold: battleGold).goldDelta
    }

    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        experienceEarnedPercent: Int = 0,
    ) -> Int {
        let raw = CombatRounding.scaled(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel,
            ),
            byPercent: experienceEarnedPercent,
        )
        return ExperienceScaling.cappedAward(
            raw,
            requiredXP: CombatantProgression.requiredXP(forLevel: playerLevel),
        )
    }

    static func grantedMaterials(
        override: [ResourceAmount]?,
        loot: BattleLootResult?,
        fallback: [ResourceAmount] = [],
    ) -> [ResourceAmount] {
        override ?? loot?.materials ?? fallback
    }

    static func grantedItem(
        override: InventoryItem?,
        loot: BattleLootResult?,
    ) -> InventoryItem? {
        override ?? loot?.item
    }

    /// Applies a battle's rewards. A pre-settled `award` from the battle that
    /// just ran wins by design: it snapshots homestead production at battle
    /// end, and re-settling at completion would accrue production a second
    /// time. Callers without a battle pass nil to settle fresh.
    ///
    /// A duplicate headline item (owned trinket/unique) converts to
    /// level-scaled consolation gold instead of granting nothing: the
    /// encounter still marks complete, so the claim must still pay something.
    static func grantVictoryRewards(
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        stageGold: Int,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        grantsCombatExperience: Bool = true,
        experienceEarnedPercent: Int = 0,
        materialRewards: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
    ) {
        var payableItem = item
        var consolationGold = 0
        if let candidate = item,
           InventoryDuplicatePolicy.containsDuplicate(of: candidate, in: save.inventory.items) {
            payableItem = nil
            let range = BattleLoot.quantityRange(forLevel: encounterLevel)
            consolationGold = (range.lowerBound + range.upperBound) / 2
        }
        let resolved = award ?? BattleRewardPlan(
            stageGold: stageGold + consolationGold,
            goldFindPercent: save.homestead.effects.goldFindPercent,
            goldFindFlat: save.homestead.effects.goldFindFlat,
            gemsFindBonus: save.homestead.effects.gemsFindBonus,
            gemsFindPercent: save.homestead.effects.gemsFindPercent,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel, roster: save.roster, percent: experienceEarnedPercent,
            ),
            heroExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: hero).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestHeroLevel,
                experienceEarnedPercent: experienceEarnedPercent + save.homestead.effects.experienceBonusPercent,
            ) + save.homestead.effects.experienceBonus : 0,
            companionExperience: grantsCombatExperience ? battleExperienceAward(
                playerLevel: save.roster.progression(for: companion).level, enemyLevel: encounterLevel,
                highestLevel: save.roster.highestCompanionLevel,
                experienceEarnedPercent: experienceEarnedPercent + save.homestead.effects.experienceBonusPercent,
            ) + save.homestead.effects.experienceBonus : 0,
            materials: materialRewards, items: payableItem.map { [$0] } ?? [],
        ).settle(
            battleGold: battleGold,
            inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
        )
        apply(resolved, hero: hero, companion: companion, save: &save)
        if grantsCombatExperience {
            save.contracts.recordVictory(encounterLevel: encounterLevel)
        }
    }

    /// Applies a settled award verbatim. Dupe conversion happens at plan
    /// construction in `grantVictoryRewards` (nil-award path); battle-end
    /// awards carry launch-filtered items, so direct `apply` callers must
    /// filter duplicates first.
    public static func apply(
        _ settlement: BattleRewardSettlement,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
    ) {
        let award = settlement.award
        if let remainders = award.rewardRemainders {
            save.homestead.rewardRemainders = remainders == .zero ? nil : remainders
        }
        let now = settlement.inputs.productionDate
        save.applyGoldDelta(award.goldDelta, at: now)
        BattleExperienceReward.apply(settlement, hero: hero, companion: companion, save: &save)
        save.grantMaterials(award.materials, at: now)
        for item in award.items {
            save.inventory.appendUniqueItem(item)
        }
    }
}
