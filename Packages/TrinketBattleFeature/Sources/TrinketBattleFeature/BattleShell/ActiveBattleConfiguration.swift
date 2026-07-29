import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Assembles a battle run from pre-resolved party, enemy, and reward inputs.
/// Mode owners / `PlayBattleLaunch` resolve encounters, loot, claimed-stage policy,
/// and gold-find percent before calling `make`.
public struct ActiveBattleConfiguration: Identifiable {
    public struct PartyMember: Equatable {
        public let combatant: Combatant
        public let progression: CombatantProgression
        public let equipmentLoadout: EquipmentLoadout
        public let modifiers: CombatModifierProfile
    }

    public let id = UUID()
    /// Journey / Spire / Labyrinth origin. `nil` is a non-progression battle.
    public let resumeToken: ActiveBattleResumeToken?
    public let rngSeed: UInt64
    public let hero: PartyMember
    public let companion: PartyMember
    public let enemy: Combatant?
    public let enemyEncounterLevel: Int?
    public let highestHeroLevel: Int
    public let highestCompanionLevel: Int
    public let enemyModifiers: CombatModifierProfile
    public let inventoryState: PlayerInventoryState
    public let stageReward: StageReward?
    public let rewardItems: [InventoryItem]
    public let pendingRewardItem: InventoryItem?
    public let experienceBonusPercent: Int
    /// Homestead gold-find baked at launch so victory display needs no live homestead.
    public let goldFindPercent: Int
    /// Journey claimed-stage policy baked at launch so Battle never reads journey progress.
    public let stageRewardsAlreadyClaimed: Bool
    public let universalModifiers: [AffixModifier]

    public var hasProgressionRewards: Bool {
        resumeToken != nil
    }

    public var stageID: String? {
        if case let .journey(stageID) = resumeToken {
            return stageID
        }
        return nil
    }

    public var labyrinthNodeID: String? {
        if case let .labyrinth(nodeID) = resumeToken {
            return nodeID
        }
        return nil
    }

    public func partyMember(for combatantID: String) -> PartyMember? {
        if combatantID == hero.combatant.id {
            return hero
        }
        if combatantID == companion.combatant.id {
            return companion
        }
        return nil
    }

    @MainActor
    public static func make(
        resumeToken: ActiveBattleResumeToken? = nil,
        rngSeed: UInt64,
        hero: Combatant,
        companion: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        homesteadState: PlayerHomesteadState = .freshStart,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) -> Self {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        let homesteadEffects = homesteadState.effects
        return Self(
            resumeToken: resumeToken,
            rngSeed: rngSeed,
            hero: partyMember(
                combatant: hero,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.heroModifiers + universalModifiers
            ),
            companion: partyMember(
                combatant: companion,
                rosterState: rosterState,
                inventoryState: inventoryState,
                additionalModifiers: homesteadEffects.companionModifiers + universalModifiers
            ),
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: rosterState.highestHeroLevel,
            highestCompanionLevel: rosterState.highestCompanionLevel,
            enemyModifiers: enemyModifiers,
            inventoryState: inventoryState,
            stageReward: stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: stageReward,
                pendingRewardItem: pendingRewardItem
            ),
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers
        )
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> PartyMember {
        let progression = rosterState.progression(for: combatant)
        let equipmentLoadout = rosterState.equipmentLoadout(for: combatant)
        let build = CombatBuildResolver.build(
            combatant: CombatantLevelScaler.scale(
                combatant: combatant,
                level: progression.level
            ),
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items,
            additionalModifiers: additionalModifiers
        )
        return PartyMember(
            combatant: build.combatant,
            progression: progression,
            equipmentLoadout: equipmentLoadout,
            modifiers: build.modifiers
        )
    }

    private static func resolvedEnemyBuild(
        enemy: Combatant?
    ) -> CombatBuild {
        guard let enemy else {
            return CombatBuild(combatant: Enemy.fallbackCombatant, modifiers: .zero)
        }
        // Preserve the encounter combatant (already scaled by PlayBattleLaunch).
        // Only resolve trait modifiers from the catalog entry — do not replace scaled stats
        // with the catalog base combatant.
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            let catalogBuild = CombatBuildResolver.build(enemy: catalogEnemy)
            return CombatBuild(combatant: enemy, modifiers: catalogBuild.modifiers)
        }
        return CombatBuild(combatant: enemy, modifiers: .zero)
    }

    private static func resolvedRewardItems(
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem]
        }
        guard let stageReward else { return [] }
        return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
    }
}
