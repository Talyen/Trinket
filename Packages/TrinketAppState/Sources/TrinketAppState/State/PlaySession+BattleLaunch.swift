import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Shared battle configuration + activation used by mode owners and the Play shell.
///
/// Encounter/loot resolve and party/reward bake live here. Battle receives a pure
/// `ActiveBattleConfiguration` DTO — no live save slices or Persistence policy inside
/// BattleFeature.
@MainActor
struct PlayBattleLaunch {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime

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
        for origin: PlayBattleOrigin?,
        enemy: Combatant? = nil,
        encounterLevel: Int = 0,
        labyrinth: PlayerLabyrinthState? = nil,
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        let enemyIsBoss = enemy.flatMap { GameContent.enemy(matching: $0.id)?.isBoss } == true
        switch origin {
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
    @discardableResult
    func activateCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        universalModifiers: [AffixModifier] = [],
        labyrinth: PlayerLabyrinthState? = nil
    ) -> Bool {
        let loot = Self.lootPackage(
            for: origin,
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            labyrinth: labyrinth,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
        let roster = playerSave.roster
        return activateBattle(
            origin: origin,
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
    @discardableResult
    func prepareCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        universalModifiers: [AffixModifier] = [],
        labyrinth: PlayerLabyrinthState? = nil
    ) -> Bool {
        let loot = Self.lootPackage(
            for: origin,
            enemy: encounter.combatant,
            encounterLevel: encounter.level,
            labyrinth: labyrinth,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
        let roster = playerSave.roster
        return battle.prepareBattleRun(makeBattleConfiguration(
            origin: origin,
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
    @discardableResult
    func activateBattle(
        origin: PlayBattleOrigin? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        if let origin,
           battle.activatePreparedBattle(
               runKey: origin.runKey,
               heroID: hero.id,
               companionID: companion.id,
               enemyID: enemy?.id
           ) {
            return true
        }
        return battle.activate(makeBattleConfiguration(
            origin: origin,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            universalModifiers: universalModifiers
        ))
    }

    func makeBattleConfiguration(
        origin: PlayBattleOrigin?,
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
        return Self.assembleConfiguration(
            runKey: origin?.runKey,
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
                origin: origin,
                journey: playerSave.journey
            ),
            universalModifiers: universalModifiers,
            defeatPrimaryAction: origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: origin != nil,
            musicStageID: origin?.musicStageID
        )
    }

    /// Bakes party builds, enemy trait modifiers, XP/materials, and presentation fields
    /// into a pure BattleFeature DTO.
    static func assembleConfiguration(
        runKey: BattleRunKey? = nil,
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
        universalModifiers: [AffixModifier] = [],
        defeatPrimaryAction: BattleDefeatPrimaryAction = .restart,
        hasProgressionRewards: Bool = false,
        musicStageID: String? = nil
    ) -> ActiveBattleConfiguration {
        let enemyBuild = resolvedEnemyBuild(enemy: enemy)
        var enemyModifiers = enemyBuild.modifiers
        enemyModifiers.merge(universalModifiers)
        let homesteadEffects = homesteadState.effects
        let heroMember = partyMember(
            combatant: hero,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.heroModifiers + universalModifiers
        )
        let companionMember = partyMember(
            combatant: companion,
            rosterState: rosterState,
            inventoryState: inventoryState,
            additionalModifiers: homesteadEffects.companionModifiers + universalModifiers
        )
        let resolvedStageReward = stageReward ?? StageReward(gold: 0, itemTemplateIDs: [])
        let enemyLevel = enemyEncounterLevel ?? heroMember.progression.level
        return ActiveBattleConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            highestHeroLevel: rosterState.highestHeroLevel,
            highestCompanionLevel: rosterState.highestCompanionLevel,
            enemyModifiers: enemyModifiers,
            inventoryItems: inventoryState.items,
            stageReward: stageReward,
            rewardItems: resolvedRewardItems(
                stageReward: stageReward,
                pendingRewardItem: pendingRewardItem
            ),
            pendingRewardItem: pendingRewardItem,
            experienceBonusPercent: experienceBonusPercent,
            goldFindPercent: homesteadEffects.goldFindPercent,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            heroExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: heroMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestHeroLevel,
                xpPercent: experienceBonusPercent
            ),
            companionExperienceAward: StageCompletion.battleExperienceAward(
                playerLevel: companionMember.progression.level,
                enemyLevel: enemyLevel,
                highestLevel: rosterState.highestCompanionLevel,
                xpPercent: experienceBonusPercent
            ),
            materialRewards: StageCompletion.resolvedMaterialRewards(stageReward: resolvedStageReward)
        )
    }

    /// Journey claimed-stage policy for battle chrome / auto-complete. Baked at launch.
    static func stageRewardsAlreadyClaimed(
        origin: PlayBattleOrigin?,
        journey: JourneyProgressState
    ) -> Bool {
        guard case let .journey(stageID) = origin,
              let stage = GameContent.stage(id: stageID)
        else { return false }
        return journey.hasClaimedRewards(for: stage)
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> ActiveBattleConfiguration.PartyMember {
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
        return ActiveBattleConfiguration.PartyMember(
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
        // Preserve the encounter combatant (already scaled by launch).
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
        let origin = activeBattle.runKey.flatMap(PlayBattleOrigin.init(runKey:))

        let configuration = battleLaunch.makeBattleConfiguration(
            origin: origin,
            hero: hero,
            companion: companion,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: activeBattle.stageReward,
            experienceBonusPercent: activeBattle.experienceBonusPercent,
            pendingRewardItem: activeBattle.pendingRewardItem,
            universalModifiers: activeBattle.universalModifiers
        )
        _ = battle.restart(configuration)
    }
}
