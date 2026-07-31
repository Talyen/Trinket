import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Shared battle launch and activation used by mode owners and the Play shell.
///
/// Encounter/loot resolve and party/build bake live here. Battle receives a pure
/// `BattleRunConfiguration`; Play keeps the separate presentation/reward context.
@MainActor
struct PlayBattleLaunch {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime
    let registerPresentation: @MainActor @Sendable (BattleRunKey, PlayBattlePresentationContext) -> Void
    let removeRun: @MainActor @Sendable (BattleRunKey) -> Void
    let removePreparedRunsExcept: @MainActor @Sendable (BattleRunKey) -> Void

    // MARK: Activate / prepare

    /// Shared activate after mode-specific gates. Modes resolve loot and policy.
    @discardableResult
    func activateCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        loot: BattleLootPackage? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction? = nil,
        musicStageID: String? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        let roster = playerSave.roster
        return activateBattle(
            origin: origin,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction ?? origin.defeatPrimaryAction,
            musicStageID: musicStageID ?? origin.musicStageID,
            universalModifiers: universalModifiers
        )
    }

    /// Shared prepare after mode-specific gates. Modes resolve loot and policy.
    @discardableResult
    func prepareCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        loot: BattleLootPackage? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction? = nil,
        musicStageID: String? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        let roster = playerSave.roster
        let launch = makeBattleLaunch(
            origin: origin,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction ?? origin.defeatPrimaryAction,
            musicStageID: musicStageID ?? origin.musicStageID,
            universalModifiers: universalModifiers
        )
        if let runKey = launch.configuration.runKey {
            registerPresentation(runKey, launch.presentation)
        }
        let prepared = battle.prepareBattleRun(launch.configuration)
        if !prepared, let runKey = launch.configuration.runKey {
            removeRun(runKey)
        }
        return prepared
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
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction? = nil,
        hasProgressionRewards: Bool? = nil,
        musicStageID: String? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        if let origin,
           battle.activatePreparedBattle(
               runKey: origin.runKey,
               heroID: hero.id,
               companionID: companion.id,
               enemyID: enemy?.id
           ) {
            removePreparedRunsExcept(origin.runKey)
            return true
        }
        let launch = makeBattleLaunch(
            origin: origin,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            universalModifiers: universalModifiers
        )
        if let runKey = launch.configuration.runKey {
            registerPresentation(runKey, launch.presentation)
        }
        let activated = battle.activate(launch.configuration)
        if !activated, let runKey = launch.configuration.runKey {
            removeRun(runKey)
        }
        return activated
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
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction? = nil,
        hasProgressionRewards: Bool? = nil,
        musicStageID: String? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> BattleRunConfiguration {
        makeBattleLaunch(
            origin: origin,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID,
            universalModifiers: universalModifiers
        ).configuration
    }

    private func makeBattleLaunch(
        origin: PlayBattleOrigin?,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        defeatPrimaryAction: BattleDefeatPrimaryAction? = nil,
        hasProgressionRewards: Bool? = nil,
        musicStageID: String? = nil,
        universalModifiers: [AffixModifier] = []
    ) -> (configuration: BattleRunConfiguration, presentation: PlayBattlePresentationContext) {
        let rngSeed = AppEnvironment.shared.battlePerformanceScenario == nil
            ? UInt64.random(in: UInt64.min ... UInt64.max)
            : BattlePerformanceFixture.seed
        return Self.assembleLaunch(
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
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: defeatPrimaryAction ?? origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: hasProgressionRewards ?? (origin != nil),
            musicStageID: musicStageID ?? origin?.musicStageID
        )
    }

    /// Bakes party builds, enemy trait modifiers, and Play-owned presentation data.
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
    ) -> BattleRunConfiguration {
        assembleLaunch(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: rosterState,
            inventoryState: inventoryState,
            homesteadState: homesteadState,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: defeatPrimaryAction,
            hasProgressionRewards: hasProgressionRewards,
            musicStageID: musicStageID
        ).configuration
    }

    static func assembleLaunch(
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
    ) -> (configuration: BattleRunConfiguration, presentation: PlayBattlePresentationContext) {
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
        let configuration = BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: heroMember,
            companion: companionMember,
            enemy: enemyBuild.combatant,
            enemyEncounterLevel: enemyEncounterLevel,
            enemyModifiers: enemyModifiers
        )
        let presentation = PlayBattlePresentationContext(
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
        return (configuration, presentation)
    }

    private static func partyMember(
        combatant: Combatant,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        additionalModifiers: [AffixModifier] = []
    ) -> BattleRunConfiguration.PartyMember {
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
        return BattleRunConfiguration.PartyMember(
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
}

public extension PlaySession {
    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let roster = playerSave.roster
        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let companion = roster.companions.first(where: { $0.id == activeBattle.companion.combatant.id })
            ?? roster.activeCompanion
        let route = route(for: activeBattle.runKey)
        guard activeBattle.runKey == nil || route != nil else {
            appStateLogger.error("Missing route for active battle restart")
            return
        }
        let origin = route?.origin
        let presentation = battlePresentation(for: activeBattle.runKey)

        let configuration = battleLaunch.makeBattleConfiguration(
            origin: origin,
            hero: hero,
            companion: companion,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: presentation?.stageReward,
            experienceBonusPercent: presentation?.experienceBonusPercent ?? 0,
            pendingRewardItem: presentation?.pendingRewardItem,
            stageRewardsAlreadyClaimed: presentation?.stageRewardsAlreadyClaimed ?? false,
            defeatPrimaryAction: presentation?.defeatPrimaryAction,
            hasProgressionRewards: presentation?.hasProgressionRewards,
            musicStageID: presentation?.musicStageID,
            universalModifiers: presentation?.universalModifiers ?? []
        )
        _ = battle.restart(configuration)
    }
}
