import Foundation
import TrinketContent
import TrinketCore

public enum AspectCompletion {
    public static func enemyLevel(for floor: AspectFloor) -> Int {
        // Mild climb curve independent of journey chapters.
        max(1, floor.floor + (floor.isWarden ? 2 : 0))
    }

    public static func complete(
        floor: AspectFloor,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
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
        save.roster.grantGold(
            save.homestead.effects.adjustedGold(floor.rewards.gold + battleEarnedGold)
        )
        grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
        grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster)

        let resolvedMaterials = StageCompletion.resolvedMaterialRewards(
            stageReward: floor.rewards,
            override: materialRewards
        )
        save.homestead.grant(resolvedMaterials)

        if let rewardItem {
            save.inventory.appendUniqueItem(rewardItem)
        } else {
            var rng = SystemRandomNumberGenerator()
            if let generated = makeAspectFloorItem(for: floor, using: &rng) {
                save.inventory.appendUniqueItem(generated)
            }
        }

        save.aspects.markFloorCleared(floor.floor, aspectID: aspectID)
    }

    /// Generates an Aspect-biased item for any cleared floor (affinity base + biased affixes).
    public static func makeAspectFloorItem(
        for floor: AspectFloor,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem? {
        guard let aspect = GameContent.aspect(id: floor.aspectID) else { return nil }

        let keywordBias: Set<Keyword> = [aspect.keyword]
        let candidates = GameContent.itemBaseTypes.filter {
            !$0.keywordAffinities.isDisjoint(with: keywordBias)
        }
        guard let baseType = candidates.randomElement(using: &randomNumberGenerator) else {
            return nil
        }

        let itemID = "aspect-\(floor.aspectID.rawValue)-floor-\(floor.floor)-\(baseType.id)"
        return ItemGenerator().generate(
            id: itemID,
            baseType: baseType,
            rarity: .basic,
            keywordBias: keywordBias,
            using: &randomNumberGenerator
        )
    }

    private static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestCompanionLevel
        let award = StageCompletion.battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
        roster.grantExperience(award, to: combatant)
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
