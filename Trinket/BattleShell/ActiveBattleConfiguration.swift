import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

struct ActiveBattleConfiguration: Identifiable {
    struct PartyMember: Equatable {
        let combatant: Combatant
        let progression: CombatantProgression
        let equipmentLoadout: EquipmentLoadout
        let modifiers: CombatModifierProfile
    }

    let id = UUID()
    /// Journey / Aspect / Labyrinth origin. `nil` is a non-progression battle.
    let resumeToken: ActiveBattleResumeToken?
    let rngSeed: UInt64
    let hero: PartyMember
    let companion: PartyMember
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
    let highestHeroLevel: Int
    let highestCompanionLevel: Int
    let enemyModifiers: CombatModifierProfile
    let inventoryState: PlayerInventoryState
    let stageReward: StageReward?
    let rewardItems: [InventoryItem]
    let pendingRewardItem: InventoryItem?
    let experienceBonusPercent: Int
    let universalModifiers: [AffixModifier]

    var hasProgressionRewards: Bool {
        resumeToken != nil
    }

    var stageID: String? {
        if case let .journey(stageID) = resumeToken {
            return stageID
        }
        return nil
    }

    var labyrinthNodeID: String? {
        if case let .labyrinth(nodeID) = resumeToken {
            return nodeID
        }
        return nil
    }

    func partyMember(for combatantID: String) -> PartyMember? {
        if combatantID == hero.combatant.id {
            return hero
        }
        if combatantID == companion.combatant.id {
            return companion
        }
        return nil
    }

    static func resolvedEncounter(
        for stage: Stage
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapters.first(where: { $0.id == stage.chapterID })
        else { return nil }

        return scaledEnemy(
            catalogEnemy,
            level: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        )
    }

    static func resolvedAspectEncounter(
        for floor: AspectFloor
    ) -> (combatant: Combatant, level: Int)? {
        guard let catalogEnemy = GameContent.enemy(matching: floor.enemyID) else { return nil }
        return scaledEnemy(catalogEnemy, level: AspectCompletion.enemyLevel(for: floor))
    }

    static func resolvedLabyrinthEncounter(
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
    static func lootPackage(
        for resumeToken: ActiveBattleResumeToken?,
        enemy: Combatant? = nil,
        encounterLevel: Int = 0,
        labyrinth: PlayerLabyrinthState? = nil
    ) -> BattleLootPackage? {
        let enemyIsBoss = enemy.flatMap { GameContent.enemy(matching: $0.id)?.isBoss } == true
        switch resumeToken {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID),
                  case .battle = stage.encounter
            else { return nil }
            return BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: encounterLevel,
                enemyIsBoss: enemyIsBoss
            )
        case let .aspect(aspectID, floorNumber):
            guard let floor = GameContent.aspectFloor(aspectID: aspectID, floor: floorNumber) else {
                return nil
            }
            return AspectCompletion.resolveLoot(for: floor)
        case let .labyrinth(nodeID):
            guard let labyrinth,
                  let node = labyrinth.node(id: nodeID),
                  node.type.isCombat
            else { return nil }
            return LabyrinthCompletion.resolveCombatLoot(
                for: node,
                effects: labyrinth.effects(for: nodeID),
                worldSeed: labyrinth.worldSeed
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
    static func make(
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
    ) -> ActiveBattleConfiguration {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        var rng = SeededRandomNumberGenerator(seed: rngSeed)
        let resolvedPendingRewardItem = pendingRewardItem
            ?? pendingAspectRewardItem(resumeToken: resumeToken, using: &rng)
        let rewardItems = resolvedRewardItems(
            resumeToken: resumeToken,
            stageReward: stageReward,
            pendingRewardItem: resolvedPendingRewardItem
        )
        let homesteadEffects = homesteadState.effects
        return ActiveBattleConfiguration(
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

    private static func pendingAspectRewardItem(
        resumeToken: ActiveBattleResumeToken?,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem? {
        _ = randomNumberGenerator
        guard case .aspect = resumeToken else { return nil }
        return lootPackage(for: resumeToken)?.item
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
        case .aspect, .labyrinth, .journey, .none:
            guard let stageReward else { return [] }
            return stageReward.itemTemplateIDs.compactMap(GameContent.itemTemplate(matching:))
        }
    }
}
