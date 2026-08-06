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
    let registerRun: @MainActor @Sendable (PlayBattleRunRegistration) -> Void
    let removeRun: @MainActor @Sendable (BattleRunKey) -> Void
    let removePreparedRunsExcept: @MainActor @Sendable (BattleRunKey) -> Void

    // MARK: Activate / prepare

    /// Shared activate after mode-specific gates. Modes resolve loot and policy.
    @discardableResult
    func activateCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        route: PlayBattleRoute? = nil,
        loot: BattleLootPackage? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        let roster = playerSave.roster
        return activateBattle(
            origin: origin,
            route: route,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers
        )
    }

    /// Shared prepare after mode-specific gates. Modes resolve loot and policy.
    @discardableResult
    func prepareCombat(
        origin: PlayBattleOrigin,
        encounter: (combatant: Combatant, level: Int),
        route: PlayBattleRoute? = nil,
        loot: BattleLootPackage? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
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
            universalModifiers: universalModifiers
        )
        guard PlayBattleRoute.matches(
            route,
            runKey: launch.configuration.runKey,
            missingLog: "Missing route for prepared battle registration"
        ) else { return false }
        let prepared = battle.prepareBattleRun(launch.configuration)
        if prepared {
            registerRunIfNeeded(launch, route: route)
        } else if let runKey = launch.configuration.runKey {
            removeRun(runKey)
        }
        return prepared
    }

    /// Installs a fresh battle configuration and syncs the tick loop.
    @discardableResult
    func activateBattle(
        origin: PlayBattleOrigin? = nil,
        route: PlayBattleRoute? = nil,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) -> Bool {
        guard PlayBattleRoute.matches(
            route,
            runKey: origin?.runKey,
            missingLog: "Missing route for battle activation"
        ) else { return false }
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
            universalModifiers: universalModifiers
        )
        let activated = battle.activate(launch.configuration)
        if activated {
            registerRunIfNeeded(launch, route: route)
        } else if let runKey = launch.configuration.runKey {
            removeRun(runKey)
        }
        return activated
    }

    func makeBattleLaunch(
        origin: PlayBattleOrigin?,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant?,
        enemyEncounterLevel: Int?,
        stageReward: StageReward?,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) -> (configuration: BattleRunConfiguration, presentation: BattlePresentationContext, universalModifiers: [AffixModifier]) {
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
            defeatPrimaryAction: origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: origin != nil,
            musicStageID: origin?.musicStageID
        )
    }

    private func registerRunIfNeeded(
        _ launch: (configuration: BattleRunConfiguration, presentation: BattlePresentationContext, universalModifiers: [AffixModifier]),
        route: PlayBattleRoute?
    ) {
        guard launch.configuration.runKey != nil, let route else { return }
        registerRun(
            PlayBattleRunRegistration(
                route: route,
                presentation: launch.presentation,
                universalModifiers: launch.universalModifiers
            )
        )
    }

    func restartActiveBattle(
        _ activeBattle: BattleRunConfiguration,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        universalModifiers: [AffixModifier]
    ) {
        let roster = playerSave.roster
        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let companion = roster.companions.first(where: { $0.id == activeBattle.companion.combatant.id })
            ?? roster.activeCompanion
        let launch = makeBattleLaunch(
            origin: route?.origin,
            hero: hero,
            companion: companion,
            enemy: activeBattle.enemy,
            enemyEncounterLevel: activeBattle.enemyEncounterLevel,
            stageReward: presentation?.stageReward,
            experienceBonusPercent: presentation?.experienceBonusPercent ?? 0,
            pendingRewardItem: presentation?.pendingRewardItem,
            stageRewardsAlreadyClaimed: presentation?.stageRewardsAlreadyClaimed ?? false,
            universalModifiers: universalModifiers
        )
        guard battle.restart(launch.configuration) else { return }
        if let route {
            registerRun(
                PlayBattleRunRegistration(
                    route: route,
                    presentation: launch.presentation,
                    universalModifiers: launch.universalModifiers
                )
            )
        }
    }
}

public extension PlaySession {
    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let route = route(for: activeBattle.runKey)
        guard PlayBattleRoute.matches(
            route,
            runKey: activeBattle.runKey,
            missingLog: "Missing route for active battle restart"
        ) else {
            return
        }
        let presentation = battlePresentation(for: activeBattle.runKey)
        guard activeBattle.runKey == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle restart")
            return
        }
        let universalModifiers = battleUniversalModifiers(for: activeBattle.runKey)
        battleLaunch.restartActiveBattle(
            activeBattle,
            route: route,
            presentation: presentation,
            universalModifiers: universalModifiers
        )
    }
}
