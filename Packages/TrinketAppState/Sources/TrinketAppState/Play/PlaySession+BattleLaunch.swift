import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

enum PlayBattleRequestResolution {
    case ready(input: BattleLaunchInput, route: PlayBattleRoute)
    case missing
    case unavailable(StageMapMessage)
}

@MainActor
final class PlayBattleLaunch {
    let playerSave: PlayerSaveStore
    let shellSession: ShellSession
    let battle: any BattleRuntime
    let runs: PlayBattleRuns
    let battlePerformanceScenario: BattlePerformanceScenario?
    var nextCombatSeed: () -> UInt64 = { UInt64.random(in: .min ... .max) }

    init(
        playerSave: PlayerSaveStore,
        shellSession: ShellSession,
        battle: any BattleRuntime,
        runs: PlayBattleRuns,
        battlePerformanceScenario: BattlePerformanceScenario?,
    ) {
        self.playerSave = playerSave
        self.shellSession = shellSession
        self.battle = battle
        self.runs = runs
        self.battlePerformanceScenario = battlePerformanceScenario
    }

    static let activationFailureMessage = StageMapMessage(
        title: "Battle Unavailable",
        message: "Could not start this battle. Try again.",
    )

    @discardableResult
    func activateCombat(_ input: BattleLaunchInput, route: PlayBattleRoute) -> Bool {
        guard playerSave.accessRestriction(for: input.origin) == nil else { return false }
        return activateBattle(input, route: route)
    }

    @discardableResult
    func activateRequest(
        _ input: BattleLaunchInput,
        route: PlayBattleRoute,
        onActivated: () -> Void = {},
    ) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return Self.activationFailureMessage }
        guard activateCombat(input, route: route) else { return Self.activationFailureMessage }
        onActivated()
        return nil
    }

    /// Single paywall → busy → resolve → activate gate for mode battle entry.
    /// Map taps (Journey/Labyrinth) pass nil and swallow a busy battle;
    /// explicit board/floor taps (Spires/Contracts) pass the failure message.
    /// A busy transient encounter is always a silent ignore.
    @discardableResult
    func startBattle(
        origin: PlayBattleOrigin,
        encounters: EncounterPlayMode,
        busyMessage: StageMapMessage?,
        resolve: () -> PlayBattleRequestResolution,
        onActivated: () -> Void = {},
    ) -> StageMapMessage? {
        if let restriction = playerSave.accessRestriction(for: origin) {
            return restriction
        }
        guard battle.lifecyclePhase != .active else { return busyMessage }
        guard encounters.canBeginTransientEncounter else { return nil }
        let request: (input: BattleLaunchInput, route: PlayBattleRoute)
        switch resolve() {
        case let .ready(input, route):
            request = (input, route)
        case .missing:
            return StageMapMessage(title: "Encounter Missing", message: "This battle is not ready yet.")
        case let .unavailable(message):
            return message
        }
        return activateRequest(request.input, route: request.route, onActivated: onActivated)
    }

    @discardableResult
    func prepareCombat(_ input: BattleLaunchInput, route: PlayBattleRoute) -> Bool {
        guard playerSave.accessRestriction(for: input.origin) == nil else { return false }
        let launch = makeBattleLaunch(input)
        return runs.prepare(launch, route: route)
    }

    func keepPreparedRuns(_ keys: Set<BattleRunKey>) {
        runs.keepPreparedRuns(keys)
    }

    func keepPreparedRuns(
        _ keys: Set<BattleRunKey>,
        preservingWhere preserve: (PlayBattleOrigin) -> Bool,
    ) {
        runs.keepPreparedRuns(keys, preservingWhere: preserve)
    }

    /// Shared single-battle pre-warm for Journey/Spires. Both warm at most one
    /// run keyed by origin. Contracts intentionally skips pre-warming: offer
    /// IDs rotate on refresh/replace, so cached runs would rarely hit.
    /// Sibling warms (including same-mode) are intentionally retained:
    /// prepared runs remain until pruning, restart, or end.
    func prepareSingleBattle(
        tracker: inout PlayBattlePreparationTracker<SingleBattlePreparationInputs>,
        origin: PlayBattleOrigin,
        stageRewardsAlreadyClaimed: Bool,
        party: PlayBattlePartySnapshot,
        makeRequest: () -> (input: BattleLaunchInput, route: PlayBattleRoute),
    ) {
        guard battle.lifecyclePhase != .active else { return }
        let inputs = SingleBattlePreparationInputs(
            runKey: origin.runKey,
            party: party,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
        )
        guard tracker.shouldPrepare(
            for: inputs,
            hasPreparedRun: battle.hasPreparedRun(origin.runKey),
        ) else { return }
        let request = makeRequest()
        if prepareCombat(request.input, route: request.route) {
            tracker.notePrepared(inputs)
        }
    }

    @discardableResult
    func activateBattle(
        _ input: BattleLaunchInput,
        route: PlayBattleRoute? = nil,
    ) -> Bool {
        guard battle.lifecyclePhase != .active,
              playerSave.accessRestriction(for: input.origin) == nil,
              playerSave.contentAccess.allowsCombatant(input.hero.id),
              playerSave.contentAccess.allowsCombatant(input.companion.id) else { return false }
        guard PlayBattleRoute.matches(
            route,
            runKey: input.origin?.runKey,
            missingLog: "Missing route for battle activation",
        ) else { return false }
        if let origin = input.origin, battle.hasPreparedRun(origin.runKey) {
            guard let registration = runs.registration(for: origin.runKey), let route,
                  registration.launch.configuration.hero.combatant.id == input.hero.id,
                  registration.launch.configuration.companion.combatant.id == input.companion.id,
                  registration.launch.configuration.enemy?.id == input.enemy?.id else { return false }
            let currentInputs = preparationInputs(input, rngSeed: registration.launch.inputs.rngSeed)
            let launch: BattleLaunchAssembly
            if currentInputs == registration.launch.inputs {
                launch = registration.launch
            } else {
                launch = Self.assembleLaunch(currentInputs)
                guard runs.prepare(launch, route: route) else { return false }
            }
            guard runs.activatePrepared(launch.configuration) else { return false }
            shellSession.selectedTab = .play
            return true
        }
        let launch = makeBattleLaunch(input)
        if launch.configuration.runKey != nil, let route {
            guard runs.prepare(launch, route: route),
                  runs.activatePrepared(launch.configuration)
            else { return false }
        } else {
            guard runs.activateStandalone(launch.configuration) else { return false }
        }
        shellSession.selectedTab = .play
        return true
    }

    private func freshRngSeed() -> UInt64 {
        battlePerformanceScenario == nil
            ? nextCombatSeed()
            : BattlePerformanceFixture.seed
    }

    func makeBattleLaunch(_ input: BattleLaunchInput) -> BattleLaunchAssembly {
        Self.assembleLaunch(preparationInputs(input, rngSeed: freshRngSeed()))
    }

    private func preparationInputs(_ input: BattleLaunchInput, rngSeed: UInt64) -> BattlePreparationInputs {
        BattlePreparationInputs(
            runKey: input.origin?.runKey, launch: input, party: PlayBattlePartySnapshot(playerSave: playerSave), rngSeed: rngSeed,
            hasProgressionRewards: input.origin != nil,
        )
    }

    func restartActiveBattle(
        _ activeBattle: BattleRunConfiguration,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        universalModifiers: [AffixModifier],
    ) -> Bool {
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
                victoryOnlyExperienceBonusPercent: presentation?.victoryOnlyExperienceBonusPercent ?? 0,
                pendingRewardItem: presentation?.pendingRewardItem,
                additionalRewardItems: presentation?.additionalRewardItems ?? [],
                stageRewardsAlreadyClaimed: presentation?.stageRewardsAlreadyClaimed ?? false,
                universalModifiers: universalModifiers,
                nodeModifiers: presentation?.nodeModifiers ?? [],
                completionBonus: presentation?.completionBonus,
            ),
        )
        guard runs.restart(launch, route: route) else { return false }
        shellSession.selectedTab = .play
        return true
    }
}

public extension PlaySession {
    @discardableResult
    func restartActiveBattle() -> StageMapMessage? {
        guard let activeBattle = battle.activeBattle else { return nil }

        let registration = battleRegistration(for: activeBattle.runKey)
        let route = registration?.route
        if let restriction = playerSave.accessRestriction(for: route?.origin) {
            endBattleReturningToOrigin()
            return restriction
        }
        guard PlayBattleRoute.matches(
            route,
            runKey: activeBattle.runKey,
            missingLog: "Missing route for active battle restart",
        ) else {
            return nil
        }
        let presentation = registration?.presentation
        guard activeBattle.runKey == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle restart")
            return nil
        }
        let universalModifiers = registration?.universalModifiers ?? []
        guard battleLaunch.restartActiveBattle(
            activeBattle,
            route: route,
            presentation: presentation,
            universalModifiers: universalModifiers,
        ) else { return PlayBattleLaunch.activationFailureMessage }
        return nil
    }
}
