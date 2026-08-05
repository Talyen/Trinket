import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore

/// Concrete, presentation-free owner for one battle lifecycle.
///
/// Play talks to this object through `BattleRuntime`. `BattleSession` observes
/// its change notifications and owns only feedback, spectacle, overlays, and
/// timing. Keeping the simulation and lifecycle here prevents app orchestration
/// from accidentally depending on BattleFeature's presentation state.
@MainActor
public final class BattleRuntimeSession: BattleRuntime {
    enum Change {
        case prepared
        case activated
        case ended
        case suspensionChanged(Bool)
        case memoryTrimmed(releaseBattleLog: Bool)
    }

    public struct PreparedBattleRun {
        public let configuration: BattleRunConfiguration
        fileprivate let state: BattleState
    }

    public struct CombatantReadModel {
        public let combatant: Combatant
        public let health: Int
        public let maxHealth: Int
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

    public struct VictoryInput {
        public let earnedGold: Int
        public let heroName: String
        public let companionName: String
    }

    /// The presentation coordinator installs this callback at the composition
    /// root. It is internal so the lifecycle contract remains closure-free.
    var onChange: (@MainActor (Change) -> Void)?

    private var state: BattleState?

    public private(set) var activeBattle: BattleRunConfiguration?
    public private(set) var lifecyclePhase: BattleLifecyclePhase = .idle
    public private(set) var isSuspendedForScenePhase = false
    public private(set) var preparedBattlePresentationRevision = 0

    private var preparedBattleRunsByKey: [BattleRunKey: PreparedBattleRun] = [:]

    var preparedBattleRuns: [PreparedBattleRun] {
        Array(preparedBattleRunsByKey.values)
    }

    var outcome: BattleSimulationOutcome? {
        BattleSimBridge.outcome(for: state)
    }

    var phase: BattlePhase? {
        state?.phase
    }

    var hasActiveSimulation: Bool {
        state != nil
    }

    var isBattleOver: Bool {
        state?.isBattleOver ?? false
    }

    var earnedGold: Int? {
        state?.earnedGold
    }

    var heroID: String? {
        state?.hero.id
    }

    var companionID: String? {
        state?.companion.id
    }

    var enemyID: String? {
        state?.enemy.id
    }

    var hand: [BattleCard] {
        state?.hand.cards ?? []
    }

    var isHeroAlive: Bool {
        state?.isHeroAlive ?? false
    }

    var isCompanionAlive: Bool {
        state?.isCompanionAlive ?? false
    }

    var logEntries: [LogEntry] {
        state?.log ?? []
    }

    var victoryInput: VictoryInput? {
        guard let state else { return nil }
        return VictoryInput(
            earnedGold: state.earnedGold,
            heroName: state.hero.name,
            companionName: state.companion.name
        )
    }

    var readModel: ReadModel? {
        guard let state else { return nil }
        let combatants = [state.hero, state.companion, state.enemy]
        return ReadModel(
            hero: state.hero,
            companion: state.companion,
            enemy: state.enemy,
            hand: state.hand.cards,
            turnCount: state.turnCount,
            earnedGold: state.earnedGold,
            isBattleOver: state.isBattleOver,
            isPartyDefeated: state.isPartyDefeated,
            events: state.events,
            log: state.log,
            healthByCombatantID: Dictionary(
                uniqueKeysWithValues: combatants.map { ($0.id, state.health(of: $0)) }
            ),
            modifiersByCombatantID: Dictionary(
                uniqueKeysWithValues: combatants.map { ($0.id, state.modifiers(for: $0.id)) }
            )
        )
    }

    func presentationSnapshot() -> BattlePresentationSnapshot? {
        guard let state, let activeBattle else { return nil }
        return BattlePresentationSnapshot(configurationID: activeBattle.id, state: state)
    }

    func openingHandArtworkNames(for preparedRun: PreparedBattleRun) -> [String] {
        var preview = preparedRun.state
        preview.drawOpeningHand(rebuildLog: false)
        return preview.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    @discardableResult
    func drawOpeningHand() -> Bool {
        guard var state else { return false }
        state.drawOpeningHand(rebuildLog: false)
        self.state = state
        return true
    }

    @discardableResult
    func drawNextOpeningHandCard() -> Bool {
        guard var state else { return false }
        let didDraw = state.drawNextOpeningHandCard(rebuildLog: false)
        self.state = state
        return didDraw
    }

    func finalizeOpeningHand() {
        guard var state else { return }
        state.finalizeOpeningHand()
        self.state = state
    }

    func isCardPlayable(_ card: BattleCard) -> Bool {
        BattleSimBridge.isCardPlayable(card, in: state)
    }

    @discardableResult
    func playCard(cardID: Int) throws -> [ActionEvent] {
        try BattleSimBridge.playCard(cardID: cardID, state: &state)
    }

    @discardableResult
    func endTurn() -> [ActionEvent] {
        BattleSimBridge.endTurn(state: &state)
    }

    func syncLog() {
        BattleSimBridge.syncLog(state: &state)
    }

    func releaseLogProjection() {
        BattleSimBridge.releaseLogProjection(state: &state)
    }

    func combatantReadModel(for combatant: Combatant) -> CombatantReadModel? {
        guard let state else { return nil }
        return CombatantReadModel(
            combatant: combatant,
            health: state.health(of: combatant),
            maxHealth: state.maxHealth(of: combatant),
            activeEffectSummaries: state.effectSummaries(of: combatant)
        )
    }

    func shouldTelegraphEnemyAttack() -> Bool {
        guard let state else { return false }
        guard state.roster.enemy.isAlive else { return false }
        return !state.roster.hasPendingActionSkip(for: state.enemy)
    }

    public init() {}

    @discardableResult
    public func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil,
              let runKey = configuration.runKey
        else { return false }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return true
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            state: BattleSimBridge.makeBattleState(from: configuration)
        )
        preparedBattlePresentationRevision += 1
        lifecyclePhase = .prepared
        onChange?(.prepared)
        return true
    }

    func preparedBattleRun(for runKey: BattleRunKey) -> PreparedBattleRun? {
        preparedBattleRunsByKey[runKey]
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.runKey == runKey,
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }

        preparedBattleRunsByKey.removeValue(forKey: runKey)
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = preparedBattleRun.configuration
        state = preparedBattleRun.state
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    @discardableResult
    public func activate(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = configuration
        state = BattleSimBridge.makeBattleState(from: configuration)
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    @discardableResult
    public func restart(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle != nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = configuration
        state = BattleSimBridge.makeBattleState(from: configuration)
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    public func endBattle() {
        activeBattle = nil
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        state = nil
        lifecyclePhase = .idle
        onChange?(.ended)
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        isSuspendedForScenePhase = suspended
        onChange?(.suspensionChanged(suspended))
    }

    public func trimMemoryFootprint(releaseBattleLog: Bool) {
        if releaseBattleLog {
            releaseLogProjection()
        }
        onChange?(.memoryTrimmed(releaseBattleLog: releaseBattleLog))
    }
}
