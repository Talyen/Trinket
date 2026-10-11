import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

extension BattleSession {
    struct VictoryInput {
        let goldFlow: BattleGoldFlow
        let heroName: String
        let companionName: String
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
        if let activeBattle {
            return engineState?.battlePresentationSnapshot(
                configurationID: activeBattle.id,
            )
        }
        guard let run = preparedPreview.selected as? PreparedBattleSimulation,
              let state = run.state(for: self) else { return nil }
        return state.battlePresentationSnapshot(
            configurationID: run.configuration.id,
        )
    }

    public var overlayBattleConfiguration: BattleRunConfiguration? {
        if let activeBattle {
            return activeBattle
        }
        return preparedPreview.selected?.configuration
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
        let result = try engineState.playCard(cardID: cardID, rebuildLog: false, recordActions: true)
        self.engineState = engineState
        return (result.events, Self.makePlayback(
            configurationID: configurationID, state: engineState, result: result, excludingCardID: cardID,
        ))
    }

    func resolveTransition(_ kind: BattleTransitionPlayback.Kind) -> BattleTransitionPlayback? {
        guard var state = engineState, let configurationID = activeBattle?.id else { return nil }
        let result: BattleCommandResult = switch kind {
        case .opening: state.drawOpeningHand(rebuildLog: false, recordActions: true)
        case .turn: state.endTurn(rebuildLog: false, recordActions: true)
        }
        engineState = state
        return Self.makePlayback(configurationID: configurationID, state: state, result: result)
    }

    private static func makePlayback(
        configurationID: UUID,
        state: BattleState,
        result: BattleCommandResult,
        excludingCardID: Int? = nil,
    ) -> BattleTransitionPlayback {
        BattleTransitionPlayback(
            configurationID: configurationID,
            snapshot: BattlePresentationSnapshot(configurationID: configurationID, state: state),
            events: result.events,
            automaticCards: result.playedCards.filter { $0.id != excludingCardID },
            actions: result.actions,
        )
    }

    func syncEngineLog() {
        mutateEngine { $0.syncLog() }
    }

    func releaseEngineLogProjection() {
        mutateEngine { $0.releaseLogProjection() }
    }

    public func createPreparedRun(_ configuration: BattleRunConfiguration) -> (any PreparedBattleRunHandle)? {
        guard activeBattle == nil, configuration.runKey != nil else { return nil }
        return PreparedBattleSimulation(
            configuration: configuration, state: makeBattleState(from: configuration),
            owner: self, generation: preparationGeneration,
        )
    }

    public func publishPreparedPreview(_ preview: BattlePreparedPreview) {
        guard preparedPreview.configurations.map(\.id) != preview.configurations.map(\.id)
            || preparedPreview.selected !== preview.selected else { return }
        preparedPreview = preview
        // Activation itself replaces the display; sibling membership is a read projection.
        if activeBattle == nil {
            preparedBattlePresentationRevision += 1
            installSimulationPresentation()
        }
        retainPreparedArtworkPins()
    }

    public func activatePreparedBattle(
        _ handle: any PreparedBattleRunHandle,
        presentation: BattlePresentationContext,
    ) -> Bool {
        guard activeBattle == nil, let prepared = handle as? PreparedBattleSimulation,
              let state = prepared.state(for: self) else { return false }
        guard installActiveBattle(prepared.configuration, state: state, presentation: presentation) else { return false }
        prepared.invalidate()
        return true
    }

    @discardableResult
    public func activate(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext = .empty,
    ) -> Bool {
        install(configuration: configuration, presentation: presentation, mode: .fresh)
    }

    @discardableResult
    public func restart(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext = .empty,
    ) -> Bool {
        install(configuration: configuration, presentation: presentation, mode: .restart)
    }

    public func endBattle() {
        activeBattle = nil
        preparationGeneration &+= 1
        preparedBattlePresentationRevision += preparedPreview.configurations.isEmpty && preparedPreview.selected == nil ? 0 : 1
        preparedPreview = .empty
        releasePreparedArtworkPins()
        engineState = nil
        clearRunState()
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        commandState.suspend(suspended)
        cardPlayback.setSuspended(suspended)
        feedback.setSuspended(suspended)
        if suspended {
            clearCardCues()
            cancelPendingAutoEnd()
        } else {
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
        preparationGeneration &+= 1
        preparedPreview = .empty
        retainPreparedArtworkPins()
        return true
    }

    private func makeBattleState(from configuration: BattleRunConfiguration) -> BattleState {
        let state = BattleState(
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
        #if DEBUG
        if configuration.runKey != nil {
            return performanceFixtureState(state)
        }
        #endif
        return state
    }
}
