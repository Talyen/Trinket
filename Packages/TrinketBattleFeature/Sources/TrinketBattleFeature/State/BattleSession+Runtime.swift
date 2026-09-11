import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

extension BattleSession {
    struct PreparedBattleRun {
        let configuration: BattleRunConfiguration
        fileprivate let state: BattleState
    }

    struct CombatantReadModel {
        let combatant: Combatant
        let health: Int
        let mana: Int
        let activeEffectSummaries: [TrinketCore.EffectSummary]
    }

    struct VictoryInput {
        let goldFlow: BattleGoldFlow
        let heroName: String
        let companionName: String
    }

    var preparedBattleRuns: [PreparedBattleRun] {
        Array(preparedBattleRunsByKey.values)
    }

    var phase: BattlePhase? {
        engineState?.phase
    }

    var isBattleOver: Bool {
        engineState?.isBattleOver ?? false
    }

    var goldFlow: BattleGoldFlow? {
        engineState?.goldFlow
    }

    var heroID: String? {
        engineState?.hero.id
    }

    var companionID: String? {
        engineState?.companion.id
    }

    var enemyID: String? {
        engineState?.enemy.id
    }

    var engineHand: [BattleCard] {
        engineState?.hand.cards ?? []
    }

    public var finalPartyHealthByCombatantID: [String: Int]? {
        guard let engineState else { return nil }
        return [
            engineState.hero.id: engineState.health(of: engineState.hero),
            engineState.companion.id: engineState.health(of: engineState.companion),
        ]
    }

    var isHeroAlive: Bool {
        engineState?.isHeroAlive ?? false
    }

    var isCompanionAlive: Bool {
        engineState?.isCompanionAlive ?? false
    }

    var victoryInput: VictoryInput? {
        guard let engineState else { return nil }
        return VictoryInput(
            goldFlow: engineState.goldFlow,
            heroName: engineState.hero.name,
            companionName: engineState.companion.name,
        )
    }

    func presentationSnapshot() -> BattlePresentationSnapshot? {
        if let snapshot = transitionPlayback?.currentSnapshot {
            return snapshot
        }
        if let activeBattle {
            return engineState?.battlePresentationSnapshot(
                configurationID: activeBattle.id,
            )
        }
        guard let run = singlePreparedBattleRun else { return nil }
        return run.state.battlePresentationSnapshot(
            configurationID: run.configuration.id,
        )
    }

    public var overlayBattleConfiguration: BattleRunConfiguration? {
        _ = preparedBattlePresentationRevision
        if let activeBattle {
            return activeBattle
        }
        return singlePreparedBattleRun?.configuration
    }

    private var singlePreparedBattleRun: PreparedBattleRun? {
        guard preparedBattleRunsByKey.count == 1 else { return nil }
        return preparedBattleRunsByKey.values.first
    }

    func openingHandArtworkNames(for state: BattleState) -> [String] {
        var preview = state
        if preview.hand.cards.isEmpty {
            preview.drawOpeningHand(rebuildLog: false)
        }
        return preview.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    func openingHandArtworkNames(for preparedRun: PreparedBattleRun) -> [String] {
        openingHandArtworkNames(for: preparedRun.state)
    }

    func activeOpeningHandArtworkNames() -> [String] {
        guard let engineState else { return [] }
        return openingHandArtworkNames(for: engineState)
    }

    func mutateEngine<T>(_ work: (inout BattleState) -> T) -> T? {
        guard var engineState else { return nil }
        let result = work(&engineState)
        self.engineState = engineState
        return result
    }

    @discardableResult
    func playEngineCard(cardID: Int) throws -> (events: [ActionEvent], playback: BattleTransitionPlayback) {
        guard var engineState, let configurationID = activeBattle?.id else { throw BattlePlayError.battleOver }
        var frames: [BattleTransitionFrame] = []
        let events = try engineState.playCard(cardID: cardID, rebuildLog: false) { checkpoint, state, events in
            let assessment: BattleCardAssessment? = if case let .cardWillPlay(card) = checkpoint {
                state.assessCard(card)
            } else {
                nil
            }
            frames.append(BattleTransitionFrame(
                checkpoint: checkpoint,
                snapshot: BattlePresentationSnapshot(configurationID: configurationID, state: state, acceptsCommands: checkpoint == .ready),
                events: events,
                assessment: assessment,
            ))
        }
        self.engineState = engineState
        return (events, BattleTransitionPlayback(configurationID: configurationID, frames: frames, initialCardID: cardID))
    }

    func resolveTransition(_ kind: BattleTransitionPlayback.Kind) -> BattleTransitionPlayback? {
        guard var state = engineState, let configurationID = activeBattle?.id else { return nil }
        var frames: [BattleTransitionFrame] = []
        let record: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void = { checkpoint, state, events in
            frames.append(BattleTransitionFrame(
                checkpoint: checkpoint,
                snapshot: BattlePresentationSnapshot(configurationID: configurationID, state: state, acceptsCommands: checkpoint == .ready),
                events: events,
            ))
        }
        switch kind {
        case .opening: _ = state.drawOpeningHand(rebuildLog: false, recording: record)
        case .turn: _ = state.endTurn(rebuildLog: false, recording: record)
        }
        engineState = state
        return BattleTransitionPlayback(configurationID: configurationID, frames: frames)
    }

    func syncEngineLog() {
        mutateEngine { $0.syncLog() }
    }

    func releaseEngineLogProjection() {
        mutateEngine { $0.releaseLogProjection() }
    }

    func shouldTelegraphEnemyAttack() -> Bool {
        guard let engineState, engineState.roster.enemy.isAlive else { return false }
        return !engineState.roster.hasPendingActionSkip(for: engineState.enemy)
    }

    func preparedBattleRun(for runKey: BattleRunKey) -> PreparedBattleRun? {
        preparedBattleRunsByKey[runKey]
    }

    @discardableResult
    public func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil, let runKey = configuration.runKey else { return false }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return true
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            state: makeBattleState(from: configuration),
        )
        retainPreparedArtworkPins()
        preparedBattlePresentationRevision += 1
        installSimulationPresentation()
        return true
    }

    public func keepPreparedRuns(_ keys: Set<BattleRunKey>) {
        guard activeBattle == nil else { return }
        let before = preparedBattleRunsByKey.count
        preparedBattleRunsByKey = preparedBattleRunsByKey.filter { keys.contains($0.key) }
        if preparedBattleRunsByKey.count != before {
            retainPreparedArtworkPins()
            preparedBattlePresentationRevision += 1
        }
        if !preparedBattleRunsByKey.isEmpty {
            installSimulationPresentation()
        }
    }

    public func hasPreparedRun(_ runKey: BattleRunKey) -> Bool {
        preparedBattleRunsByKey.index(forKey: runKey) != nil
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        configurationID: UUID,
    ) -> Bool {
        guard activeBattle == nil,
              let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.id == configurationID
        else { return false }

        guard installActiveBattle(preparedBattleRun.configuration, state: preparedBattleRun.state) else { return false }
        preparedBattleRunsByKey.removeValue(forKey: runKey)
        return true
    }

    @discardableResult
    public func activate(_ configuration: BattleRunConfiguration) -> Bool {
        activate(configuration, presentation: nil)
    }

    @discardableResult
    public func activate(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext?,
    ) -> Bool {
        install(configuration: configuration, presentation: presentation, mode: .fresh)
    }

    @discardableResult
    public func restart(_ configuration: BattleRunConfiguration) -> Bool {
        restart(configuration, presentation: nil)
    }

    @discardableResult
    public func restart(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext?,
    ) -> Bool {
        install(configuration: configuration, presentation: presentation, mode: .restart)
    }

    public func endBattle() {
        activeBattle = nil
        if !preparedBattleRunsByKey.isEmpty {
            preparedBattlePresentationRevision += 1
        }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        releasePreparedArtworkPins()
        engineState = nil
        clearRunState()
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        commandState.suspend(suspended)
        cardPlayback.isSuspended = suspended
        if suspended {
            clearCardCues()
            cancelPendingAutoEnd()
        } else {
            restoreRecordedCardCue()
            scheduleAutoEndIfNeeded()
        }
    }

    public func trimMemoryFootprint(releaseBattleLog: Bool) {
        if lifecyclePhase == .idle {
            releasePreparedArtworkPins()
        }
        if releaseBattleLog {
            releaseEngineLogProjection()
        }
        trimPresentationMemory()
    }

    private enum BattleInstallMode {
        case fresh
        case restart
    }

    @discardableResult
    private func install(
        configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext?,
        mode: BattleInstallMode,
    ) -> Bool {
        switch mode {
        case .fresh:
            guard activeBattle == nil else { return false }
        case .restart:
            guard activeBattle != nil else { return false }
        }
        guard installActiveBattle(
            configuration, state: makeBattleState(from: configuration), presentation: presentation,
        ) else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        retainPreparedArtworkPins()
        return true
    }

    private func makeBattleState(from configuration: BattleRunConfiguration) -> BattleState {
        BattleState(
            hero: configuration.hero.combatant,
            companion: configuration.companion.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            companionModifiers: configuration.companion.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            heroStartingHealth: configuration.hero.startingHealth,
            companionStartingHealth: configuration.companion.startingHealth,
            enemyFaction: configuration.enemyFaction,
            rngSeed: configuration.rngSeed,
            tracksLog: false,
            dealOpeningHand: false,
        )
    }
}
