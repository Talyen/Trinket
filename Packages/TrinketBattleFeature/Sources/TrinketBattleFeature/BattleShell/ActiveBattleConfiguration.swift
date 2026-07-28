import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

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

    public static func resolvedEncounter(
        for stage: Stage
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = stage.resolvedBattleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }

        return scaledEnemy(
            catalogEnemy,
            level: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        )
    }

    public static func resolvedSpireEncounter(
        for floor: SpireFloor
    ) -> (combatant: Combatant, level: Int)? {
        guard let catalogEnemy = GameContent.enemy(matching: floor.enemyID) else { return nil }
        return scaledEnemy(catalogEnemy, level: SpireCompletion.enemyLevel(for: floor))
    }

    public static func resolvedLabyrinthEncounter(
        for node: LabyrinthNode
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = node.enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        return scaledEnemy(
            catalogEnemy,
            level: LabyrinthCompletion.enemyLevel(for: node)
        )
    }

    /// Seeded combat loot for battle chrome and grant paths. Pure formulas stay in Persistence.
    public static func lootPackage(
        for resumeToken: ActiveBattleResumeToken?,
        enemy: Combatant? = nil,
        encounterLevel: Int = 0,
        labyrinth: PlayerLabyrinthState? = nil,
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        let enemyIsBoss = enemy.flatMap { GameContent.enemy(matching: $0.id)?.isBoss } == true
        switch resumeToken {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID),
                  stage.encounter.isCombat
            else { return nil }
            return BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss,
                astralChanceBonusPercent: astralChanceBonusPercent
            )
        case let .spire(spireID, floorNumber):
            guard let floor = GameContent.spireFloor(spireID: spireID, floor: floorNumber) else {
                return nil
            }
            return SpireCompletion.resolveLoot(
                for: floor,
                astralChanceBonusPercent: astralChanceBonusPercent
            )
        case let .labyrinth(nodeID):
            guard let labyrinth,
                  let node = labyrinth.node(id: nodeID),
                  node.type.isCombat
            else { return nil }
            return LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: labyrinth.effects(for: nodeID),
                worldSeed: labyrinth.worldSeed,
                astralChanceBonusPercent: astralChanceBonusPercent
            )
        case .none:
            return nil
        }
    }

    private static func scaledEnemy(
        _ enemy: Enemy,
        level: Int
    ) -> (combatant: Combatant, level: Int) {
        (CombatantLevelScaler.scale(enemy: enemy, level: level), level)
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
        universalModifiers: [AffixModifier] = []
    ) -> Self {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        var rng = SeededRandomNumberGenerator(seed: rngSeed)
        let resolvedPendingRewardItem = pendingRewardItem
            ?? pendingSpireRewardItem(
                resumeToken: resumeToken,
                astralChanceBonusPercent: homesteadState.effects.astralChanceBonusPercent,
                using: &rng
            )
        let rewardItems = resolvedRewardItems(
            resumeToken: resumeToken,
            stageReward: stageReward,
            pendingRewardItem: resolvedPendingRewardItem
        )
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
            rewardItems: rewardItems,
            pendingRewardItem: resolvedPendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            universalModifiers: universalModifiers
        )
    }

    private static func pendingSpireRewardItem(
        resumeToken: ActiveBattleResumeToken?,
        astralChanceBonusPercent: Int,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem? {
        _ = randomNumberGenerator
        guard case .spire = resumeToken else { return nil }
        return lootPackage(
            for: resumeToken,
            astralChanceBonusPercent: astralChanceBonusPercent
        )?.item
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
        // Preserve the encounter combatant (already journey-scaled by `resolvedEncounter`).
        // Only resolve trait modifiers from the catalog entry — do not replace scaled stats
        // with the catalog base combatant.
        if let catalogEnemy = GameContent.enemy(matching: enemy.id) {
            let catalogBuild = CombatBuildResolver.build(enemy: catalogEnemy)
            return CombatBuild(combatant: enemy, modifiers: catalogBuild.modifiers)
        }
        return CombatBuild(combatant: enemy, modifiers: .zero)
    }

    private static func resolvedRewardItems(
        resumeToken: ActiveBattleResumeToken?,
        stageReward: StageReward?,
        pendingRewardItem: InventoryItem?
    ) -> [InventoryItem] {
        if let pendingRewardItem {
            return [pendingRewardItem]
        }
        switch resumeToken {
        case .spire, .labyrinth, .journey, .none:
            guard let stageReward else { return [] }
            return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
        }
    }

    /// Maps Labyrinth damage-dealt bonuses into battle-wide affix modifiers.
    public static func labyrinthCombatModifiers(
        from effects: LabyrinthModifierEffects
    ) -> [AffixModifier] {
        effects.damageDealtBonus
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageDealt($0.key, $0.value) }
    }
}
