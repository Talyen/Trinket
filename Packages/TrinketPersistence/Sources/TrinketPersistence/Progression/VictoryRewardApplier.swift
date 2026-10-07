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

    /// Resolves encounter rewards that have no settled battle award.
    /// A duplicate headline item (owned trinket/unique) converts to
    /// level-scaled consolation gold instead of granting nothing: the
    /// encounter still marks complete, so the claim must still pay something.
    static func grantVictoryRewards(
        party: (hero: Combatant, companion: Combatant),
        encounterLevel: Int,
        stageGold: Int,
        battleGold: BattleGoldFlow = .init(),
        grantsCombatExperience: Bool = true,
        experienceEarnedPercent: Int = 0,
        materialRewards: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
        claim: CloudEconomicAction.Claim? = nil,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) {
        let (hero, companion) = party
        let resolved = settleVictoryRewards(
            party: party, encounterLevel: encounterLevel, stageGold: stageGold, battleGold: battleGold,
            grantsCombatExperience: grantsCombatExperience, experienceEarnedPercent: experienceEarnedPercent,
            materialRewards: materialRewards, item: item, save: save,
        )
        apply(resolved, hero: hero, companion: companion, save: &save, claim: claim, recordReceipt: recordReceipt)
        if grantsCombatExperience {
            save.contracts.recordVictory(encounterLevel: encounterLevel)
        }
    }

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
        var consolationGold = 0
        if let candidate = loot.item,
           InventoryDuplicatePolicy.containsDuplicate(of: candidate, in: save.inventory.items) {
            payableItem = nil
            let range = BattleLoot.quantityRange(forLevel: encounterLevel)
            consolationGold = (range.lowerBound + range.upperBound) / 2
        }
        let effects = save.homestead.effects
        func experience(for combatant: Combatant, highestLevel: Int) -> Int {
            guard grantsCombatExperience else { return 0 }
            return battleExperienceAward(
                playerLevel: save.roster.progression(for: combatant).level,
                enemyLevel: encounterLevel,
                highestLevel: highestLevel,
                experienceEarnedPercent: experienceEarnedPercent + effects.experienceBonusPercent,
            ) + effects.experienceBonus
        }
        return BattleRewardPlan(
            stageGold: SaturatedArithmetic.saturatingAdd(stageGold, consolationGold),
            goldFindPercent: effects.goldFindPercent,
            goldFindFlat: effects.goldFindFlat,
            gemsFindBonus: effects.gemsFindBonus,
            gemsFindPercent: effects.gemsFindPercent,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel, roster: save.roster, percent: experienceEarnedPercent,
            ),
            heroExperience: experience(for: party.hero, highestLevel: save.roster.highestHeroLevel),
            companionExperience: experience(for: party.companion, highestLevel: save.roster.highestCompanionLevel),
            materials: loot.materials, items: payableItem.map { [$0] } ?? [],
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
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) {
        apply(settlement, hero: hero, companion: companion, save: &save, claim: nil, recordReceipt: recordReceipt)
    }

    static func apply(
        _ settlement: BattleRewardSettlement, hero: Combatant, companion: Combatant,
        save: inout PlayerSave, claim: CloudEconomicAction.Claim?,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) {
        let award = settlement.award
        let before = save.homestead.rewardRemainders ?? .zero
        if let remainders = award.rewardRemainders {
            save.homestead.rewardRemainders = remainders == .zero ? nil : remainders
        }
        let now = settlement.inputs.productionDate
        let gold = save.applyGoldDelta(award.goldDelta, at: now)
        let experience = BattleExperienceReward.apply(settlement, hero: hero, companion: companion, save: &save, recordReceipt: { _ in })
            .effects.experience
        let materials = save.grantMaterials(award.materials, at: now)
        for item in award.items {
            save.inventory.appendUniqueItem(item)
        }
        let after = save.homestead.rewardRemainders ?? .zero
        recordReceipt(SaveEconomicReceipt(kind: .reward, effects: .committed(
            claim: claim, gold: gold, materials: Dictionary(uniqueKeysWithValues: materials.map { ($0.resource, $0.quantity) }),
            experience: experience, goldRemainder: after.gold - before.gold, gemsRemainder: after.gems - before.gems,
        )))
    }
}
