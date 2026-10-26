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
            SaturatedArithmetic.saturatingAdd(2, max(0, node.depth))
        case .battle, .boss, .entrance:
            0
        }
    }

    @discardableResult
    static func complete(
        nodeID: String,
        hero: Combatant,
        companion: Combatant,
        rewards: EncounterRewards = .unsettled(.init()),
        save: inout PlayerSave,
        access: ContentAccessPolicy = .fullGame,
    ) -> EncounterCompletion {
        let eligibleRecruitEventIDs = save.roster.eligibleRecruitEventIDs(access: access)
        save.labyrinth.ensureMap(
            seed: save.worldSeed,
            eligibleRecruitEventIDs: eligibleRecruitEventIDs,
            eligibleRewards: RewardOwnership(save).eligibleModifiers,
        )
        guard let node = save.labyrinth.node(id: nodeID) else { return .unavailable }
        guard !node.isCleared else { return .alreadyCompleted }

        let scaling = EncounterScaling.labyrinth(authoredLevel: EncounterLevelResolver.labyrinthEnemyLevel(for: node))
        let encounterLevel = rewards.encounterLevel(or: scaling.resolve(partyAverageLevel: save.roster.activePartyAverageLevel).level)
        let isCombat = node.type.isCombat
        let settlement = rewards.resolve { overrides in
            let effects = save.labyrinth.effects(for: nodeID)
            let resolvedLoot = isCombat
                ? overrides.loot ?? BattleLootContext(save: save, worldSeed: save.labyrinth.worldSeed).labyrinth(
                    for: node,
                    effects: effects,
                    encounterLevel: encounterLevel,
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
