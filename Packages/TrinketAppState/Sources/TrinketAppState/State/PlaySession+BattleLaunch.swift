import BattleEngine
import Foundation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Shared battle configuration + activation used by mode owners and the Play shell.
///
/// Encounter and loot resolution for launch live here (orchestration).
/// `ActiveBattleConfiguration.make` only assembles pre-resolved inputs.
@MainActor
struct PlayBattleLaunch {
    let playerSave: PlayerSaveStore
    let battle: BattleSession

    // MARK: Encounter resolution

    static func resolvedEncounter(
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

    static func resolvedSpireEncounter(
        for floor: SpireFloor
    ) -> (combatant: Combatant, level: Int)? {
        guard let catalogEnemy = GameContent.enemy(matching: floor.enemyID) else { return nil }
        return scaledEnemy(catalogEnemy, level: SpireCompletion.enemyLevel(for: floor))
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

    /// Maps Labyrinth damage-dealt bonuses into battle-wide affix modifiers.
    static func labyrinthCombatModifiers(
        from effects: LabyrinthModifierEffects
    ) -> [AffixModifier] {
        effects.damageDealtBonus
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageDealt($0.key, $0.value) }
    }

    // MARK: Activate / prepare

    /// Shared activate after mode-specific gates. Resolves loot from the save homestead.
    func activateCombat(
        resumeToken: ActiveBattleResumeToken,
        encounter: (combatant: Combatant, level: Int),
        universalModifiers: [AffixModifier] = [],
        labyrinth: PlayerLabyrinthState? = nil
    ) {
        let loot = Self.lootPackage(
            for: resumeToken,
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            labyrinth: labyrinth,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
        let roster = playerSave.roster
        activateBattle(
            resumeToken: resumeToken,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            universalModifiers: universalModifiers
        )
    }

    /// Shared prepare after mode-specific gates. Resolves loot from the save homestead.
    func prepareCombat(
        resumeToken: ActiveBattleResumeToken,
        encounter: (combatant: Combatant, level: Int),
        universalModifiers: [AffixModifier] = [],
        labyrinth: PlayerLabyrinthState? = nil
    ) {
        let loot = Self.lootPackage(
            for: resumeToken,
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            labyrinth: labyrinth,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
        let roster = playerSave.roster
        battle.prepareBattleRun(makeBattleConfiguration(
            resumeToken: resumeToken,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            universalModifiers: universalModifiers
        ))
    }

    /// Installs a fresh battle configuration and syncs the tick loop.
    func activateBattle(
        resumeToken: ActiveBattleResumeToken? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) {
        if let resumeToken,
           battle.activatePreparedBattle(
               resumeToken: resumeToken,
               heroID: hero.id,
               companionID: companion.id,
               enemyID: enemy?.id
           ) {
            return
        }
        battle.activeBattle = makeBattleConfiguration(
            resumeToken: resumeToken,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            universalModifiers: universalModifiers
        )
    }

    func makeBattleConfiguration(
        resumeToken: ActiveBattleResumeToken?,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> ActiveBattleConfiguration {
        let rngSeed = AppEnvironment.shared.battlePerformanceScenario == nil
            ? UInt64.random(in: UInt64.min ... UInt64.max)
            : BattlePerformanceFixture.seed
        return ActiveBattleConfiguration.make(
            resumeToken: resumeToken,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: playerSave.roster,
            inventoryState: playerSave.inventory,
            homesteadState: playerSave.homestead,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: Self.stageRewardsAlreadyClaimed(
                resumeToken: resumeToken,
                journey: playerSave.journey
            ),
            universalModifiers: universalModifiers
        )
    }

    /// Journey claimed-stage policy for battle chrome / auto-complete. Baked at launch.
    static func stageRewardsAlreadyClaimed(
        resumeToken: ActiveBattleResumeToken?,
        journey: JourneyProgressState
    ) -> Bool {
        guard case let .journey(stageID) = resumeToken,
              let stage = GameContent.stage(id: stageID)
        else { return false }
        return journey.hasClaimedRewards(for: stage)
    }

    private static func scaledEnemy(
        _ enemy: Enemy,
        level: Int
    ) -> (combatant: Combatant, level: Int) {
        (CombatantLevelScaler.scale(enemy: enemy, level: level), level)
    }
}

public extension PlaySession {
    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let roster = playerSave.roster
        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let companion = roster.companions.first(where: { $0.id == activeBattle.companion.combatant.id })
            ?? roster.activeCompanion

        battleLaunch.activateBattle(
            resumeToken: activeBattle.resumeToken,
            hero: hero,
            companion: companion,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            experienceBonusPercent: activeBattle.experienceBonusPercent,
            pendingRewardItem: activeBattle.pendingRewardItem,
            universalModifiers: activeBattle.universalModifiers
        )
    }
}
