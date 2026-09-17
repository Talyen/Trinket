import Foundation
import TrinketContent
import TrinketCore

/// Outcome of an encounter completion call. Completions are idempotent:
/// duplicate deliveries (double-tap, silent retry, deferred flush) report
/// `.alreadyCompleted` and grant nothing further instead of paying twice.
public enum EncounterCompletion: Equatable, Sendable {
    case completed
    case alreadyCompleted
    case unavailable
}

public enum StageCompletion {
    public static func resolvedMaterialRewards(
        stageReward: StageReward,
        override: [ResourceAmount]? = nil,
    ) -> [ResourceAmount] {
        override ?? stageReward.materialRewards.filter { $0.resource != .gold && $0.quantity > 0 }
    }

    public static func resolveLoot(
        for stage: Stage,
        encounterLevel: Int? = nil,
        enemyIsBoss: Bool? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0,
        in chapters: [Chapter] = GameContent.chapters,
    ) -> BattleLootResult {
        let level = encounterLevel ?? resolvedEncounterLevel(for: stage, in: chapters)
        let isBoss = enemyIsBoss ?? VictoryRewardApplier.isBoss(enemyID: stage.encounter.battleEnemyID)
        return VictoryRewardApplier.resolveLoot(
            .journey(stage: stage, chapters: chapters),
            encounterLevel: level,
            enemyIsBoss: isBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func resolvedEncounterLevel(for stage: Stage, in chapters: [Chapter]) -> Int {
        guard let chapter = chapters.first(where: { $0.id == stage.chapterID }) else {
            return 1
        }
        return EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
    }

    public static func partyAdjustedEncounterLevel(
        for stage: Stage,
        in chapters: [Chapter] = GameContent.chapters,
        save: PlayerSave,
    ) -> Int {
        EncounterLevelResolver.campaignAdjusted(
            resolvedEncounterLevel(for: stage, in: chapters),
            partyAverageLevel: save.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    public static func complete(
        _ stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        in chapters: [Chapter],
        save: inout PlayerSave,
    ) -> EncounterCompletion {
        let claim = claimRewardsIfNeeded(
            for: stage,
            hero: hero,
            companion: companion,
            battleGold: battleGold,
            award: award,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
            save: &save,
        )
        guard !save.journey.isCompleted(stage) else {
            return claim
        }
        save.journey.complete(stage, in: chapters)
        return .completed
    }

    @discardableResult
    public static func completeEncounter(
        stage: Stage,
        labyrinthNodeID: String?,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        in chapters: [Chapter],
        save: inout PlayerSave,
    ) -> EncounterCompletion {
        if let labyrinthNodeID {
            return LabyrinthCompletion.complete(
                nodeID: labyrinthNodeID,
                hero: hero,
                companion: companion,
                battleGold: battleGold,
                award: award,
                materialRewards: materialRewards,
                rewardItem: rewardItem,
                loot: loot,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
        }
        return complete(
            stage,
            hero: hero,
            companion: companion,
            battleGold: battleGold,
            award: award,
            materialRewards: materialRewards,
            rewardItem: rewardItem,
            loot: loot,
            enemyEncounterLevel: enemyEncounterLevel,
            in: chapters,
            save: &save,
        )
    }

    @discardableResult
    public static func claimRewardsIfNeeded(
        for stage: Stage,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) -> EncounterCompletion {
        guard !save.journey.hasClaimedRewards(for: stage) else {
            return .alreadyCompleted
        }

        let encounterLevel = enemyEncounterLevel
            ?? partyAdjustedEncounterLevel(for: stage, save: save)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: stage.encounter.battleEnemyID)

        let resolvedLoot: BattleLootResult? = {
            if let loot {
                return loot
            }
            guard stage.encounter.isCombat else {
                return nil
            }
            return resolveLoot(
                for: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss,
                worldSeed: save.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            )
        }()

        let stageGold: Int
        let materialFallback: [ResourceAmount]
        if stage.encounter.isCombat {
            // Combat payouts come entirely from the seeded loot roll; authored
            // stage rewards never stack on top (all shipped stages author
            // `.empty` — see JourneyCatalogTests). Non-combat stages have no
            // loot roll, so their authored rewards apply directly.
            stageGold = resolvedLoot?.gold ?? 0
            materialFallback = []
        } else {
            stageGold = stage.rewards.gold
            materialFallback = resolvedMaterialRewards(stageReward: stage.rewards)
        }
        let item = VictoryRewardApplier.grantedItem(override: rewardItem, loot: resolvedLoot)
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: stageGold,
            battleGold: battleGold,
            award: award,
            grantsCombatExperience: stage.encounter.isCombat,
            materialRewards: VictoryRewardApplier.grantedMaterials(
                override: materialRewards,
                loot: resolvedLoot,
                fallback: materialFallback,
            ),
            item: item,
            save: &save,
        )
        if award == nil, item == nil {
            grantAuthoredItems(for: stage, inventory: &save.inventory)
        }

        save.journey.markRewardsClaimed(for: stage)
        return .completed
    }

    private static func grantAuthoredItems(for stage: Stage, inventory: inout PlayerInventoryState) {
        for templateID in stage.rewards.itemTemplateIDs {
            guard let template = GameContent.itemTemplate(matching: templateID) else { continue }
            inventory.addRewardItem(from: template, for: stage)
        }
    }
}
