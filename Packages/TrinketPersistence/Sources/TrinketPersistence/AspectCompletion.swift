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
        pet: Combatant,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        save: inout PlayerSave
    ) {
        let encounterLevel = enemyLevel(for: floor)
        save.roster.grantGold(floor.rewards.gold + battleEarnedGold)
        grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster)
        grantBattleExperience(enemyLevel: encounterLevel, to: pet, roster: &save.roster)

        let resolvedMaterials = materialRewards
            ?? save.homestead.adjustedMaterialRewards(floor.rewards.materialRewards)
        save.homestead.grant(resolvedMaterials)
        save.aspects.markFloorCleared(floor.floor, aspectID: floor.aspectID.rawValue)
    }

    private static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestPetLevel
        let award = StageCompletion.battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel
        )
        roster.grantExperience(award, to: combatant)
    }
}

public enum AspectUnlock {
    /// Iron Vein is always available once Modes exists. Other Aspects unlock from Iron Vein progress.
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
