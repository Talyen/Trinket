import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
struct PlayBattleLaunch {
    let playerSave: PlayerSaveStore
    let shellSession: ShellSession
    let battle: any BattleRuntime
    let runRegistry: PlayBattleRunRegistry
    let battlePerformanceScenario: BattlePerformanceScenario?

    static let activationFailureMessage = StageMapMessage(
        title: "Battle Unavailable",
        message: "Could not start this battle. Try again.",
    )

    @discardableResult
    func activateCombat(_ request: PlayCombatRequest) -> Bool {
        activateBattle(
            makeLaunchInput(for: request),
            route: request.route,
        )
    }

    @discardableResult
    func prepareCombat(_ request: PlayCombatRequest) -> Bool {
        let launch = makeBattleLaunch(makeLaunchInput(for: request))
        guard PlayBattleRoute.matches(
            request.route,
            runKey: launch.configuration.runKey,
            missingLog: "Missing route for prepared battle registration",
        ) else { return false }
        let prepared = battle.prepareBattleRun(launch.configuration)
        if prepared {
            registerRunIfNeeded(launch, route: request.route)
        } else if let runKey = launch.configuration.runKey {
            runRegistry.remove(runKey)
        }
        return prepared
    }

    func keepPreparedRuns(_ keys: Set<BattleRunKey>) {
        battle.keepPreparedRuns(keys)
        runRegistry.keep(keys)
    }

    @discardableResult
    func activateBattle(
        _ input: BattleLaunchInput,
        route: PlayBattleRoute? = nil,
    ) -> Bool {
        guard PlayBattleRoute.matches(
            route,
            runKey: input.origin?.runKey,
            missingLog: "Missing route for battle activation",
        ) else { return false }
        if let origin = input.origin {
            if battle.activatePreparedBattle(
                runKey: origin.runKey,
                heroID: input.hero.id,
                companionID: input.companion.id,
                enemyID: input.enemy?.id,
            ) {
                shellSession.selectedTab = .play
                return true
            }
            if battle.hasPreparedRun(origin.runKey) {
                return false
            }
        }
        let launch = makeBattleLaunch(input)
        let activated = battle.activate(launch.configuration)
        if activated {
            registerRunIfNeeded(launch, route: route)
            shellSession.selectedTab = .play
        } else if let runKey = launch.configuration.runKey,
                  !battle.hasPreparedRun(runKey),
                  battle.activeBattle == nil {
            runRegistry.remove(runKey)
        }
        return activated
    }

    private func makeLaunchInput(for request: PlayCombatRequest) -> BattleLaunchInput {
        let roster = playerSave.roster
        if request.loot == nil {
            assertionFailure("Combat launched without pre-rolled loot; Victory screen will not match granted rewards.")
        }
        return BattleLaunchInput(
            origin: request.origin,
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: request.encounter.combatant,
            enemyEncounterLevel: request.encounter.level,
            stageReward: request.loot?.asStageReward ?? .empty,
            pendingRewardItem: request.loot?.item,
            stageRewardsAlreadyClaimed: request.stageRewardsAlreadyClaimed,
            universalModifiers: request.universalModifiers,
            labyrinthModifiers: request.labyrinthModifiers,
        )
    }

    func makeBattleLaunch(_ input: BattleLaunchInput) -> BattleLaunchAssembly {
        let rngSeed = battlePerformanceScenario == nil
            ? UInt64.random(in: UInt64.min ... UInt64.max)
            : BattlePerformanceFixture.seed
        return Self.assembleLaunch(
            input: input,
            runKey: input.origin?.runKey,
            rngSeed: rngSeed,
            rosterState: playerSave.roster,
            inventoryState: playerSave.inventory,
            homesteadState: playerSave.homestead,
            defeatPrimaryAction: input.origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: input.origin != nil,
            musicStageID: input.origin?.musicStageID,
        )
    }

    private func registerRunIfNeeded(
        _ launch: BattleLaunchAssembly,
        route: PlayBattleRoute?,
    ) {
        guard launch.configuration.runKey != nil, let route else { return }
        runRegistry.register(
            PlayBattleRunRegistration(
                route: route,
                presentation: launch.presentation,
                universalModifiers: launch.universalModifiers,
            ),
        )
    }

    func restartActiveBattle(
        _ activeBattle: BattleRunConfiguration,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        universalModifiers: [AffixModifier],
    ) {
        let roster = playerSave.roster
        let hero = roster.heroes.first(where: { $0.id == activeBattle.hero.combatant.id })
            ?? roster.activeHero
        let companion = roster.companions.first(where: { $0.id == activeBattle.companion.combatant.id })
            ?? roster.activeCompanion
        let launch = makeBattleLaunch(
            BattleLaunchInput(
                origin: route?.origin,
                hero: hero,
                companion: companion,
                enemy: activeBattle.enemy,
                enemyEncounterLevel: activeBattle.enemyEncounterLevel,
                stageReward: presentation?.stageReward,
                experienceBonusPercent: presentation?.experienceBonusPercent ?? 0,
                pendingRewardItem: presentation?.pendingRewardItem,
                stageRewardsAlreadyClaimed: presentation?.stageRewardsAlreadyClaimed ?? false,
                universalModifiers: universalModifiers,
                labyrinthModifiers: presentation?.labyrinthModifiers ?? [],
            ),
        )
        guard battle.restart(launch.configuration) else { return }
        shellSession.selectedTab = .play
        registerRunIfNeeded(launch, route: route)
    }
}

public extension PlaySession {
    func restartActiveBattle() {
        guard let activeBattle = battle.activeBattle else { return }

        let registration = battleRegistration(for: activeBattle.runKey)
        let route = registration?.route
        guard PlayBattleRoute.matches(
            route,
            runKey: activeBattle.runKey,
            missingLog: "Missing route for active battle restart",
        ) else {
            return
        }
        let presentation = registration?.presentation
        guard activeBattle.runKey == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle restart")
            return
        }
        let universalModifiers = registration?.universalModifiers ?? []
        battleLaunch.restartActiveBattle(
            activeBattle,
            route: route,
            presentation: presentation,
            universalModifiers: universalModifiers,
        )
    }
}
