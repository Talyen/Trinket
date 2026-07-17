import Foundation
import TrinketContent
import TrinketCore

public enum AspectCompletion {
    public static func enemyLevel(for floor: AspectFloor) -> Int {
        let isBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        return max(1, floor.floor + (isBoss ? 2 : 0))
    }

    public static func resolveLoot(for floor: AspectFloor) -> BattleLootPackage {
        let encounterLevel = enemyLevel(for: floor)
        let enemyIsBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
        let keywordBias: Set<Keyword> = {
            guard let aspect = GameContent.aspect(id: floor.aspectID) else { return [] }
            return [aspect.keyword]
        }()
        return BattleLoot.resolveAspect(
            floor: floor,
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            keywordBias: keywordBias
        )
    }

    public static func complete(
        floor: AspectFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootPackage? = nil,
        save: inout PlayerSave
    ) {
        let aspectID = floor.aspectID.rawValue
        let floorCount = GameContent.aspect(id: floor.aspectID)?.floorCount ?? floor.floor
        guard !save.aspects.isFloorCleared(floor.floor, aspectID: aspectID) else {
            return
        }
        guard save.aspects.isFloorStartable(floor.floor, aspectID: aspectID),
              save.aspects.isFloorUnlocked(
                  floor.floor,
                  aspectID: aspectID,
                  floorCount: floorCount
              )
        else {
            return
        }

        let encounterLevel = enemyLevel(for: floor)
        let resolvedLoot = loot ?? resolveLoot(for: floor)
        save.roster.grantGold(
            save.homestead.effects.adjustedGold(resolvedLoot.gold + battleEarnedGold)
        )
        StageCompletion.grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
        StageCompletion.grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)

        let resolvedMaterials = materialRewards ?? resolvedLoot.materials
        save.homestead.grant(resolvedMaterials)

        if let rewardItem {
            save.inventory.appendUniqueItem(rewardItem)
        } else {
            save.inventory.appendUniqueItem(resolvedLoot.item)
        }

        save.aspects.markFloorCleared(floor.floor, aspectID: aspectID)
    }

    /// Generates an Aspect floor item (same seed path as `resolveLoot`).
    public static func makeAspectFloorItem(
        for floor: AspectFloor,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem? {
        _ = randomNumberGenerator
        return resolveLoot(for: floor).item
    }
}

public enum AspectUnlock {
    /// Iron Vein is available from the Explore hub. Other Aspects unlock from Iron Vein progress.
    public static func isUnlocked(
        _ aspect: AspectDefinition,
        progress: PlayerAspectsState
    ) -> Bool {
        if aspect.id == .ironVein {
            return true
        }
        let ironCleared = progress.highestClearedFloor(for: AspectID.ironVein.rawValue)
        if aspect.id == .cinderSpire || aspect.id == .serpentHollow {
            return ironCleared >= 5
        }
        return ironCleared >= 10
    }

    public static func unlockHint(for aspect: AspectDefinition) -> String {
        if aspect.id == .ironVein {
            return ""
        }
        if aspect.id == .cinderSpire || aspect.id == .serpentHollow {
            return "Clear Iron Vein Floor 5"
        }
        return "Clear Iron Vein Floor 10"
    }
}
