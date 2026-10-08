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

extension PlayBattleCoordinator {
    static let activationFailureMessage = StageMapMessage(
        title: "Battle Unavailable",
        message: "Could not start this battle. Try again.",
    )

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
        return activateBattle(request.input, route: request.route) ? nil : Self.activationFailureMessage
    }

    @discardableResult
    func prepareCombat(_ input: BattleLaunchInput, route: PlayBattleRoute) -> Bool {
        guard battle.lifecyclePhase != .active,
              playerSave.accessRestriction(for: input.origin) == nil,
              PlayBattleRoute.matches(
                  route, runKey: input.origin?.runKey,
                  missingLog: "Missing route for prepared battle registration",
              ) else { return false }
        let launch: BattleLaunchAssembly
        if let runKey = input.origin?.runKey, preparedRuns[runKey] != nil,
           let registration = registration(for: runKey) {
            // The registered snapshot owns freshness and RNG for this run.
            // Refreshing inputs must not reroll combat or rebuild sibling runs.
            let inputs = preparationInputs(input, rngSeed: registration.launch.inputs.rngSeed)
            if inputs == registration.launch.inputs {
                return true
            }
            launch = Self.assembleLaunch(inputs)
        } else {
            launch = makeBattleLaunch(input)
        }
        return prepare(launch, route: route)
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
        if let origin = input.origin {
            if preparedRuns[origin.runKey] != nil {
                guard let registration = registration(for: origin.runKey),
                      registration.launch.configuration.hero.combatant.id == input.hero.id,
                      registration.launch.configuration.companion.combatant.id == input.companion.id,
                      registration.launch.configuration.enemy?.id == input.enemy?.id else { return false }
            }
            guard let route else { return false }
            guard prepareCombat(input, route: route),
                  let launch = registration(for: origin.runKey)?.launch,
                  activatePrepared(launch.configuration) else { return false }
        } else {
            guard activateStandalone(makeBattleLaunch(input)) else { return false }
        }
        shellSession.selectedTab = .play
        return true
    }

    private func freshRngSeed() -> UInt64 {
        battlePerformanceScenario == nil
            ? nextCombatSeed()
            : BattlePerformanceFixture.seed
    }

    private func makeBattleLaunch(_ input: BattleLaunchInput) -> BattleLaunchAssembly {
        Self.assembleLaunch(preparationInputs(input, rngSeed: freshRngSeed()))
    }

    private func preparationInputs(_ input: BattleLaunchInput, rngSeed: UInt64) -> BattlePreparationInputs {
        BattlePreparationInputs(
            launch: input, party: PlayBattlePartySnapshot(playerSave: playerSave), rngSeed: rngSeed,
        )
    }

    func requestRestart(onFinished: () -> Void) -> StageMapMessage? {
        if case .victory = claimState {
            return Self.activationFailureMessage
        }
        guard let configuration = battle.activeBattle,
              let run = activeRegistration(for: configuration) else { return nil }
        if let restriction = playerSave.accessRestriction(for: run.route?.origin) {
            endBattleReturningToOrigin(onFinished: onFinished)
            return restriction
        }
        guard restartActiveBattle(configuration) else { return Self.activationFailureMessage }
        return nil
    }

    func restartActiveBattle(_ configuration: BattleRunConfiguration) -> Bool {
        guard let run = activeRun, run.launch.configuration.id == configuration.id,
              battle.activeBattle?.id == configuration.id else { return false }
        let original = run.launch.inputs.launch
        let roster = playerSave.roster
        let hero = roster.heroes.first { $0.id == configuration.hero.combatant.id } ?? roster.activeHero
        let companion = roster.companions.first { $0.id == configuration.companion.combatant.id } ?? roster.activeCompanion
        let launch = makeBattleLaunch(BattleLaunchInput(
            origin: original.origin, hero: hero, companion: companion,
            enemy: original.enemy, enemyEncounterLevel: original.enemyEncounterLevel,
            stageReward: original.stageReward,
            experienceBonusPercent: original.experienceBonusPercent,
            victoryOnlyExperienceBonusPercent: original.victoryOnlyExperienceBonusPercent,
            pendingRewardItem: original.pendingRewardItem,
            additionalRewardItems: original.additionalRewardItems,
            stageRewardsAlreadyClaimed: original.stageRewardsAlreadyClaimed,
            universalModifiers: original.universalModifiers,
            nodeModifiers: original.nodeModifiers, completionBonus: original.completionBonus,
        ))
        guard restart(launch, route: run.route) else { return false }
        shellSession.selectedTab = .play
        return true
    }
}
