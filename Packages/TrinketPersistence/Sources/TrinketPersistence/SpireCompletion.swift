import Foundation
import TrinketContent
import TrinketCore

public enum SpireCompletion {
    public static func resolveLoot(
        for floor: SpireFloor,
        encounterLevel: Int? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String>,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootResult {
        let level = encounterLevel ?? EncounterLevelResolver.spireEnemyLevel(for: floor)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: floor.enemyID)
        return VictoryRewardApplier.resolveLoot(
            .spire(floor: floor),
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

    public static func complete(
        floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) {
        let spireID = floor.spireID.rawValue
        guard let spire = GameContent.spire(id: floor.spireID) else {
            return
        }
        guard !save.spires.isFloorCleared(floor.floor, spireID: spireID) else {
            return
        }
        guard save.spires.isFloorStartable(
            floor.floor,
            spireID: spireID,
            floorCount: spire.floorCount,
        ) else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? EncounterLevelResolver.partyAdjusted(
                EncounterLevelResolver.spireEnemyLevel(for: floor),
                partyAverageLevel: save.roster.activePartyAverageLevel,
            )
        let resolvedLoot = loot ?? resolveLoot(
            for: floor,
            encounterLevel: encounterLevel,
            worldSeed: save.worldSeed,
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: resolvedLoot.gold,
            battleEarnedGold: battleEarnedGold,
            materialRewards: VictoryRewardApplier.grantedMaterials(
                override: materialRewards,
                loot: resolvedLoot,
            ),
            item: VictoryRewardApplier.grantedItem(override: rewardItem, loot: resolvedLoot),
            save: &save,
        )

        save.spires.markFloorCleared(floor.floor, spireID: spireID)
    }
}
