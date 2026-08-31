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
        let earnedGold: Int
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

    var earnedGold: Int? {
        engineState?.earnedGold
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

    var pendingBoonOffer: BoonOffer? {
        engineState?.pendingBoonOffer
    }

    var activeBoons: [ActiveBoon] {
        engineState?.activeBoons ?? []
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
            earnedGold: engineState.earnedGold,
            heroName: engineState.hero.name,
            companionName: engineState.companion.name,
        )
    }

    func presentationSnapshot() -> BattlePresentationSnapshot? {
        if let activeBattle {
            return engineState?.battlePresentationSnapshot(
                configurationID: activeBattle.id,
                isEnemyTurnActive: isEnemyTurnActive,
            )
        }
        guard let run = singlePreparedBattleRun else { return nil }
        return run.state.battlePresentationSnapshot(
            configurationID: run.configuration.id,
            isEnemyTurnActive: isEnemyTurnActive,
        )
    }

    func beginEnemyTurnIfNeeded() {
        guard !isEnemyTurnActive else { return }
        enemyTurnGeneration &+= 1
        pendingEnemyTurnResetTask?.cancel()
        pendingEnemyTurnResetTask = nil
        isEnemyTurnActive = true
        installSimulationPresentation()
    }

    func scheduleEnemyTurnReset(after date: Date = .now) {
        let generation = enemyTurnGeneration
        let feedbackDelay = feedback.latestExpiry.map {
            max(0, $0.timeIntervalSince(date))
        } ?? 0
        let resetDelay = max(0.26, feedbackDelay)
        pendingEnemyTurnResetTask?.cancel()
        pendingEnemyTurnResetTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(resetDelay))
            guard !Task.isCancelled, enemyTurnGeneration == generation else { return }
            isEnemyTurnActive = false
            pendingEnemyTurnResetTask = nil
            installSimulationPresentation()
        }
    }

    func cancelPendingEnemyTurnReset() {
        pendingEnemyTurnResetTask?.cancel()
        pendingEnemyTurnResetTask = nil
    }

    func finishEnemyTurnPresentation() {
        guard isEnemyTurnActive else { return }
        cancelPendingEnemyTurnReset()
        isEnemyTurnActive = false
        installSimulationPresentation()
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

    func openingHandArtworkNames(for preparedRun: PreparedBattleRun) -> [String] {
        var preview = preparedRun.state
        preview.drawOpeningHand(rebuildLog: false)
        return preview.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    func activeOpeningHandArtworkNames() -> [String] {
        guard var preview = engineState else { return [] }
        if preview.hand.cards.isEmpty {
            preview.drawOpeningHand(rebuildLog: false)
        }
        return preview.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    @discardableResult
    func drawOpeningHand() -> [ActionEvent] {
        guard var engineState else { return [] }
        let events = engineState.drawOpeningHand(rebuildLog: false)
        self.engineState = engineState
        return events
    }

    @discardableResult
    func drawNextOpeningHandCard() -> Bool {
        guard var engineState else { return false }
        let didDraw = engineState.drawNextOpeningHandCard(rebuildLog: false)
        self.engineState = engineState
        return didDraw
    }

    @discardableResult
    func finalizeOpeningHand() -> [ActionEvent] {
        guard var engineState else { return [] }
        let events = engineState.finalizeOpeningHand()
        self.engineState = engineState
        return events
    }

    @discardableResult
    func playEngineCard(cardID: Int) throws -> [ActionEvent] {
        guard var engineState else { throw BattlePlayError.battleOver }
        let events = try engineState.playCard(cardID: cardID, rebuildLog: false)
        self.engineState = engineState
        return events
    }

    @discardableResult
    func endEngineTurn() -> [ActionEvent] {
        guard var engineState else { return [] }
        let events = engineState.endTurn(rebuildLog: false)
        self.engineState = engineState
        return events
    }

    @discardableResult
    func selectBoon(id: String) -> Bool {
        guard var engineState, engineState.selectBoon(id: id) else { return false }
        self.engineState = engineState
        installSimulationPresentation()
        scheduleAutoEndIfNeeded()
        return true
    }

    @discardableResult
    func selectAutoBoon() -> Bool {
        guard let offer = pendingBoonOffer, let engineState,
              let choiceID = BoonEngine.autoSelectedChoiceID(for: offer, in: engineState)
        else { return false }
        return selectBoon(id: choiceID)
    }

    func syncEngineLog() {
        guard var engineState else { return }
        engineState.syncLog()
        self.engineState = engineState
    }

    func releaseEngineLogProjection() {
        guard var engineState else { return }
        engineState.releaseLogProjection()
        self.engineState = engineState
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
        releasePreparedArtworkPins()
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            state: makeBattleState(from: configuration),
        )
        preparedBattlePresentationRevision += 1
        lifecyclePhase = .prepared
        installSimulationPresentation()
        return true
    }

    public func keepPreparedRuns(_ keys: Set<BattleRunKey>) {
        guard activeBattle == nil else { return }
        let before = preparedBattleRunsByKey.count
        preparedBattleRunsByKey = preparedBattleRunsByKey.filter { keys.contains($0.key) }
        if preparedBattleRunsByKey.count != before {
            preparedBattlePresentationRevision += 1
        }
        if preparedBattleRunsByKey.isEmpty {
            lifecyclePhase = .idle
        } else {
            installSimulationPresentation()
        }
    }

    public func hasPreparedRun(_ runKey: BattleRunKey) -> Bool {
        preparedBattleRunsByKey.index(forKey: runKey) != nil
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?,
    ) -> Bool {
        guard activeBattle == nil,
              let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }

        engineState = preparedBattleRun.state
        activatePresentation(
            for: preparedBattleRun.configuration,
            presentation: presentationContext,
        )
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
        guard activeBattle == nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        releasePreparedArtworkPins()
        engineState = makeBattleState(from: configuration)
        activatePresentation(for: configuration, presentation: presentation)
        return true
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
        guard activeBattle != nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        releasePreparedArtworkPins()
        engineState = makeBattleState(from: configuration)
        activatePresentation(for: configuration, presentation: presentation)
        return true
    }

    public func endBattle() {
        activeBattle = nil
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        releasePreparedArtworkPins()
        engineState = nil
        lifecyclePhase = .idle
        clearRunState()
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        isSuspendedForScenePhase = suspended
        if suspended {
            cancelPendingAutoEnd()
            finishEnemyTurnPresentation()
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

    private func activatePresentation(
        for configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext? = nil,
    ) {
        installActiveBattle(configuration, presentation: presentation)
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
