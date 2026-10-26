import Foundation
import TrinketContent
import TrinketCore

public enum VictoryRewardApplier {
    public static func isBoss(enemyID: String?) -> Bool {
        guard let enemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }

    /// Resolves encounter rewards that have no settled battle award.
    /// Duplicate headline items convert to level-scaled consolation Gold.
    static func settleVictoryRewards(
        party: (hero: Combatant, companion: Combatant),
        encounterLevel: Int,
        stageGold: Int,
        battleGold: BattleGoldFlow = .init(),
        grantsCombatExperience: Bool = true,
        experienceEarnedPercent: Int = 0,
        materialRewards: [ResourceAmount],
        item: InventoryItem?,
        save: PlayerSave,
    ) -> BattleRewardSettlement {
        let (hero, companion) = party
        return unpreparedRewardPlan(
            party: (hero, companion), encounterLevel: encounterLevel,
            stageGold: stageGold, grantsCombatExperience: grantsCombatExperience,
            experienceEarnedPercent: experienceEarnedPercent,
            loot: (materialRewards, item), save: save,
        ).settle(
            battleGold: battleGold,
            inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
        )
    }

    private static func unpreparedRewardPlan(
        party: (hero: Combatant, companion: Combatant),
        encounterLevel: Int,
        stageGold: Int,
        grantsCombatExperience: Bool,
        experienceEarnedPercent: Int,
        loot: (materials: [ResourceAmount], item: InventoryItem?),
        save: PlayerSave,
    ) -> BattleRewardPlan {
        var payableItem = loot.item
        let consolationGold: Int
        if let candidate = loot.item,
           InventoryDuplicatePolicy.containsDuplicate(of: candidate, in: save.inventory.items) {
            payableItem = nil
            consolationGold = BattleLoot.duplicateItemConsolationGold(forLevel: encounterLevel)
        } else {
            consolationGold = 0
        }
        return BattleRewardPlan.forEncounter(
            party: (save.roster.progression(for: party.hero), save.roster.progression(for: party.companion)),
            highestLevels: (save.roster.highestHeroLevel, save.roster.highestCompanionLevel),
            encounterLevel: encounterLevel,
            homestead: save.homestead,
            stageGold: SaturatedArithmetic.saturatingAdd(stageGold, consolationGold),
            materials: loot.materials, items: payableItem.map { [$0] } ?? [],
            experienceEarnedPercent: experienceEarnedPercent,
            grantsCombatExperience: grantsCombatExperience,
        )
    }

    /// Applies a settled award verbatim. Dupe conversion happens at plan
    /// construction in `settleVictoryRewards`; battle-end
    /// awards carry launch-filtered items, so direct `apply` callers must
    /// filter duplicates first.
    static func apply(
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
        _ = save.applyGoldDelta(award.goldDelta, at: now)
        BattleExperienceReward.apply(settlement, hero: hero, companion: companion, save: &save)
        _ = save.grantMaterials(award.materials, at: now)
        for item in award.items {
            save.inventory.appendUniqueItem(item)
        }
    }
}
