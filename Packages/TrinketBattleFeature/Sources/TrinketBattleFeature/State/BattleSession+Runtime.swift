import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

extension BattleSession {
    public struct PreparedBattleRun {
        public let configuration: BattleRunConfiguration
        fileprivate let state: BattleState
    }

    public struct CombatantReadModel {
        public let combatant: Combatant
        public let health: Int
        public let maxHealth: Int
        public let mana: Int
        public let activeEffectSummaries: [TrinketCore.EffectSummary]
    }

    public struct ReadModel {
        public let hero: Combatant
        public let companion: Combatant
        public let enemy: Combatant
        public let hand: [BattleCard]
        public let turnCount: Int
        public let earnedGold: Int
        public let isBattleOver: Bool
        public let isPartyDefeated: Bool
        public let events: [ActionEvent]
        public let log: [LogEntry]
        public let healthByCombatantID: [String: Int]
        public let modifiersByCombatantID: [String: CombatModifierProfile]
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
            companionName: engineState.companion.name
        )
    }

    var readModel: ReadModel? {
        guard let engineState else { return nil }
        let combatants = [engineState.hero, engineState.companion, engineState.enemy]
        return ReadModel(
            hero: engineState.hero,
            companion: engineState.companion,
            enemy: engineState.enemy,
            hand: engineState.hand.cards,
            turnCount: engineState.turnCount,
            earnedGold: engineState.earnedGold,
            isBattleOver: engineState.isBattleOver,
            isPartyDefeated: engineState.isPartyDefeated,
            events: engineState.events,
            log: engineState.log,
            healthByCombatantID: Dictionary(
                uniqueKeysWithValues: combatants.map { ($0.id, engineState.health(of: $0)) }
            ),
            modifiersByCombatantID: Dictionary(
                uniqueKeysWithValues: combatants.map { ($0.id, engineState.modifiers(for: $0.id)) }
            )
        )
    }

    func presentationSnapshot() -> BattlePresentationSnapshot? {
        guard let activeBattle else { return nil }
        return engineState?.battlePresentationSnapshot(configurationID: activeBattle.id)
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
            state: makeBattleState(from: configuration)
        )
        preparedBattlePresentationRevision += 1
        lifecyclePhase = .prepared
        return true
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }

        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        releasePreparedArtworkPins()
        engineState = preparedBattleRun.state
        activatePresentation(for: preparedBattleRun.configuration)
        return true
    }

    @discardableResult
    public func activate(_ configuration: BattleRunConfiguration) -> Bool {
        activate(configuration, presentation: nil)
    }

    @discardableResult
    public func activate(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext?
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
        presentation: BattlePresentationContext?
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
        } else {
            scheduleAutoEndIfNeeded()
        }
    }

    public func trimMemoryFootprint(releaseBattleLog: Bool) {
        releasePreparedArtworkPins()
        if releaseBattleLog {
            releaseEngineLogProjection()
        }
        trimPresentationMemory()
    }

    private func activatePresentation(
        for configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext? = nil
    ) {
        activeBattle = configuration
        lifecyclePhase = .active
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
            rngSeed: configuration.rngSeed,
            tracksLog: false,
            dealOpeningHand: false
        )
    }
}
