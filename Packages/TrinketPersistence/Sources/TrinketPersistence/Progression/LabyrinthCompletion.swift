import Foundation
import TrinketContent
import TrinketCore

public enum LabyrinthCompletion {
    public static func enter(save: inout PlayerSave, access: ContentAccessPolicy = .fullGame) {
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: access),
            eligibleRewards: RewardOwnership(save).eligibleModifiers,
        )
    }

    public static func nonCombatGoldStipend(for node: LabyrinthNode) -> Int {
        switch node.type {
        case .shop, .mystery, .recruit:
            2 + node.depth
        case .battle, .boss, .entrance:
            0
        }
    }

    public static func rewardItemID(forNodeID nodeID: String) -> String {
        "labyrinth-\(nodeID)"
    }

    public static func resolveCombatLoot(
        for node: LabyrinthNode,
        effects: NodeModifierEffects,
        encounterLevel: Int? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootResult? {
        guard node.type.isCombat else { return nil }
        let level = encounterLevel ?? EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: node.enemyID)
        return BattleLoot.resolve(
            .labyrinth(node: node, effects: effects),
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: RewardOwnership(
                ownedTrinketIDs: ownedTrinketIDs,
                ownedUniqueIDs: ownedUniqueIDs,
            ),
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    @discardableResult
    static func complete(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        rewards: EncounterRewards = .unsettled(.init()),
        save: inout PlayerSave,
        access: ContentAccessPolicy = .fullGame,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> EncounterCompletion {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs(access: access)
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            eligibleRewards: RewardOwnership(save).eligibleModifiers,
        )
        guard let node = save.labyrinth.node(id: nodeID) else { return .unavailable }
        guard !node.isCleared else { return .alreadyCompleted }

        let encounterLevel = rewards.encounterLevel(or: EncounterLevelResolver.labyrinthAdjusted(
            EncounterLevelResolver.labyrinthEnemyLevel(for: node),
            partyAverageLevel: save.roster.activePartyAverageLevel,
        ))
        let isCombat = node.type.isCombat
        let settlement = rewards.resolve { overrides in
            let effects = save.labyrinth.effects(for: nodeID)
            let resolvedLoot = isCombat
                ? overrides.loot ?? resolveCombatLoot(
                    for: node,
                    effects: effects,
                    encounterLevel: encounterLevel,
                    worldSeed: save.worldSeed,
                    ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                    ownedUniqueIDs: save.inventory.ownedUniqueIDs,
                    astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
                )
                : overrides.loot
            return VictoryRewardApplier.settleVictoryRewards(
                party: (hero, companion),
                encounterLevel: encounterLevel,
                stageGold: isCombat ? resolvedLoot?.gold ?? 0 : nonCombatGoldStipend(for: node),
                battleGold: overrides.battleGold,
                grantsCombatExperience: isCombat,
                experienceEarnedPercent: isCombat ? effects.experienceEarnedPercent : 0,
                materialRewards: overrides.materialRewards ?? resolvedLoot?.materials ?? [],
                item: overrides.rewardItem ?? resolvedLoot?.item,
                save: save,
            )
        }
        VictoryRewardApplier.apply(
            settlement, hero: hero, companion: companion, save: &save,
            claim: .labyrinth(seed: save.labyrinth.worldSeed, nodeID: nodeID), recordReceipt: recordReceipt,
        )
        if isCombat {
            save.contracts.recordVictory(encounterLevel: encounterLevel)
        }

        save.labyrinth.markCleared(
            nodeID: nodeID,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            eligibleRewards: RewardOwnership(save).eligibleModifiers,
        )
        return .completed
    }
}
