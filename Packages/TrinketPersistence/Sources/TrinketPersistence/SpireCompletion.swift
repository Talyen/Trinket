import Foundation
import TrinketContent
import TrinketCore

public enum SpireCompletion {
    public static func resolveLoot(
        for floor: SpireFloor,
        encounterLevel: Int? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage {
        let level = encounterLevel ?? EncounterLevelResolver.spireEnemyLevel(for: floor)
        let enemyIsBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        let keywordBias: Set<Keyword> = {
            guard let spire = GameContent.spire(id: floor.spireID) else { return [] }
            return [spire.keyword]
        }()
        return BattleLoot.resolveSpire(
            floor: floor,
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            keywordBias: keywordBias,
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    public static func complete(
        floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave
    ) {
        let spireID = floor.spireID.rawValue
        let floorCount = GameContent.spire(id: floor.spireID)?.floorCount ?? floor.floor
        guard !save.spires.isFloorCleared(floor.floor, spireID: spireID) else {
            return
        }
        guard save.spires.isFloorStartable(floor.floor, spireID: spireID),
              save.spires.isFloorUnlocked(
                  floor.floor,
                  spireID: spireID,
                  floorCount: floorCount
              )
        else {
            return
        }

        let encounterLevel = enemyEncounterLevel
            ?? EncounterLevelResolver.partyAdjusted(
                EncounterLevelResolver.spireEnemyLevel(for: floor),
                partyAverageLevel: save.roster.activePartyAverageLevel
            )
        let resolvedLoot = loot ?? resolveLoot(
            for: floor,
            encounterLevel: encounterLevel,
            worldSeed: save.worldSeed,
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
        )
        StageCompletion.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: resolvedLoot.gold,
            battleEarnedGold: battleEarnedGold,
            materials: materialRewards ?? resolvedLoot.materials,
            item: rewardItem ?? resolvedLoot.item,
            save: &save
        )

        save.spires.markFloorCleared(floor.floor, spireID: spireID)
    }
}
