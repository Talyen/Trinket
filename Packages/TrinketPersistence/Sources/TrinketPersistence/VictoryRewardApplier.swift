import Foundation
import TrinketContent
import TrinketCore

public struct LootRequest: Sendable {
    public var seedSalt: String
    public var itemID: String
    public var keywordBias: Set<Keyword>
    public var goldFoundPercent: Int
    public var materialsFoundPercent: Int

    public init(
        seedSalt: String,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
    ) {
        self.seedSalt = seedSalt
        self.itemID = itemID
        self.keywordBias = keywordBias
        self.goldFoundPercent = goldFoundPercent
        self.materialsFoundPercent = materialsFoundPercent
    }
}

public struct RewardOwnership: Sendable {
    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }

    public init(_ inventory: PlayerInventoryState) {
        ownedTrinketIDs = inventory.ownedTrinketIDs
        ownedUniqueIDs = inventory.ownedUniqueIDs
    }

    public init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}

public enum VictoryRewardApplier {
    public static func isBoss(enemyID: String?) -> Bool {
        guard let enemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        goldFindPercent: Int,
    ) -> Int {
        let earned = max(0, stageGold) + battleEarnedGold
        let scaled = CombatRounding.scaled(earned, byPercent: goldFindPercent)
        return max(0, scaled)
    }

    public static func resolvedGoldReward(
        stageGold: Int,
        battleEarnedGold: Int,
        homestead: PlayerHomesteadState,
    ) -> Int {
        resolvedGoldReward(
            stageGold: stageGold,
            battleEarnedGold: battleEarnedGold,
            goldFindPercent: homestead.effects.goldFindPercent,
        )
    }

    public static func battleExperienceAward(
        playerLevel: Int,
        enemyLevel: Int,
        highestLevel: Int,
        xpPercent: Int = 0,
    ) -> Int {
        let raw = CombatRounding.scaled(
            ExperienceScaling.battleAwardWithCatchUp(
                playerLevel: playerLevel,
                enemyLevel: enemyLevel,
                highestLevel: highestLevel,
            ),
            byPercent: xpPercent,
        )
        return ExperienceScaling.cappedAward(
            raw,
            requiredXP: CombatantProgression.requiredXP(forLevel: playerLevel),
        )
    }

    public static func grantBattleExperience(
        enemyLevel: Int,
        to combatant: Combatant,
        roster: inout PlayerRosterState,
        xpPercent: Int = 0,
    ) {
        let playerLevel = roster.progression(for: combatant).level
        let highestLevel = combatant.role == .hero
            ? roster.highestHeroLevel
            : roster.highestCompanionLevel
        let award = battleExperienceAward(
            playerLevel: playerLevel,
            enemyLevel: enemyLevel,
            highestLevel: highestLevel,
            xpPercent: xpPercent,
        )
        roster.grantExperience(award, to: combatant)
    }

    public static func resolveLoot(
        _ request: LootRequest,
        encounterLevel: Int,
        enemyIsBoss: Bool,
        worldSeed: UInt64,
        ownership: RewardOwnership,
        astralChanceBonusPercent: Int = 0,
    ) -> BattleLootPackage {
        var rng = SeededRandomNumberGenerator(
            seed: GameContent.encounterSeed(worldSeed, salt: request.seedSalt),
        )
        return BattleLoot.resolve(
            encounterLevel: encounterLevel,
            enemyIsBoss: enemyIsBoss,
            itemID: request.itemID,
            keywordBias: request.keywordBias,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            goldFoundPercent: request.goldFoundPercent,
            materialsFoundPercent: request.materialsFoundPercent,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &rng,
        )
    }

    static func grantVictoryRewards(
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        stageGold: Int,
        battleEarnedGold: Int = 0,
        grantsCombatExperience: Bool = true,
        xpPercent: Int = 0,
        materials: [ResourceAmount],
        item: InventoryItem?,
        save: inout PlayerSave,
    ) {
        let now = Date()
        save.applyGoldDelta(
            resolvedGoldReward(
                stageGold: stageGold,
                battleEarnedGold: battleEarnedGold,
                homestead: save.homestead,
            ),
            at: now,
        )
        if grantsCombatExperience {
            grantBattleExperience(enemyLevel: encounterLevel, to: hero, roster: &save.roster, xpPercent: xpPercent)
            grantBattleExperience(enemyLevel: encounterLevel, to: companion, roster: &save.roster, xpPercent: xpPercent)
        }
        save.grantMaterials(materials, at: now)
        if let item {
            save.inventory.appendUniqueItem(item)
        }
    }
}
