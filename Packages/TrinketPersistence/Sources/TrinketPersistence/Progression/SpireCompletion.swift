import Foundation
import TrinketContent
import TrinketCore

enum SpireCompletion {
    @discardableResult
    static func complete(
        floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        rewards: EncounterRewards = .unsettled(.init()),
        save: inout PlayerSave,
    ) -> EncounterCompletion {
        let spireID = floor.spireID.rawValue
        guard let spire = GameContent.spire(id: floor.spireID) else {
            return .unavailable
        }
        guard !save.spires.isFloorCleared(floor.floor, spireID: spireID) else {
            return .alreadyCompleted
        }
        guard save.spires.isFloorStartable(
            floor.floor,
            spireID: spireID,
            floorCount: spire.floorCount,
        ) else {
            return .unavailable
        }

        let scaling = EncounterScaling.spire(authoredLevel: EncounterLevelResolver.spireEnemyLevel(for: floor))
        let encounterLevel = rewards.encounterLevel(or: scaling.resolve(partyAverageLevel: save.roster.activePartyAverageLevel).level)
        let settlement = rewards.resolve { overrides in
            let resolvedLoot = overrides.loot ?? BattleLootContext(save: save).spire(for: floor, encounterLevel: encounterLevel)
            return VictoryRewardApplier.settleVictoryRewards(
                party: (hero, companion),
                encounterLevel: encounterLevel,
                stageGold: resolvedLoot.gold,
                battleGold: overrides.battleGold,
                materialRewards: overrides.materialRewards ?? resolvedLoot.materials,
                item: overrides.rewardItem ?? resolvedLoot.item,
                save: save,
            )
        }
        VictoryRewardApplier.apply(
            settlement, hero: hero, companion: companion, save: &save,
        )
        save.contracts.recordVictory(encounterLevel: encounterLevel)

        save.spires.markFloorCleared(floor.floor, spireID: spireID)
        return .completed
    }
}
