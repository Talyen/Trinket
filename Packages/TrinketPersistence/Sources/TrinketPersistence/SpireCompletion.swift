import Foundation
import TrinketContent
import TrinketCore

public enum SpireCompletion {
    public static func enemyLevel(for floor: SpireFloor) -> Int {
        let isBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        let baseLevel = Int(pow(Double(floor.floor), 1.5).rounded())
        return max(1, baseLevel + (isBoss ? 2 : 0))
    }

    public static func resolveLoot(
        for floor: SpireFloor,
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage {
        let encounterLevel = enemyLevel(for: floor)
        let enemyIsBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        let keywordBias: Set<Keyword> = {
            guard let spire = GameContent.spire(id: floor.spireID) else { return [] }
            return [spire.keyword]
        }()
        return BattleLoot.resolveSpire(
            floor: floor,
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            keywordBias: keywordBias,
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

        let encounterLevel = enemyLevel(for: floor)
        let resolvedLoot = loot ?? resolveLoot(
            for: floor,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
        )
        save.grantGold(
            save.homestead.effects.adjustedGold(resolvedLoot.gold + battleEarnedGold)
        )
        StageCompletion.grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
        StageCompletion.grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)

        let resolvedMaterials = materialRewards ?? resolvedLoot.materials
        save.grantMaterials(resolvedMaterials)

        if let rewardItem {
            save.inventory.appendUniqueItem(rewardItem)
        } else {
            save.inventory.appendUniqueItem(resolvedLoot.item)
        }

        save.spires.markFloorCleared(floor.floor, spireID: spireID)
    }

    /// Generates a Spire floor item (same seed path as `resolveLoot`).
    public static func makeSpireFloorItem(
        for floor: SpireFloor,
        astralChanceBonusPercent: Int = 0
    ) -> InventoryItem {
        resolveLoot(
            for: floor,
            astralChanceBonusPercent: astralChanceBonusPercent
        ).item
    }
}
