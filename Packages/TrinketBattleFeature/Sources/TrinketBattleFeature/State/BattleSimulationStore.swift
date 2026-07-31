import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

/// Owns the mutable engine value for one BattleFeature lifecycle.
///
/// `BattleState` is deliberately private to this store. Callers receive commands,
/// projections, and small read models instead of a value they could mutate outside
/// the BattleSession lifecycle.
@MainActor
final class BattleSimulationStore {
    struct PreparedRun {
        fileprivate let state: BattleState
        fileprivate let configurationID: UUID
    }

    struct CombatantReadModel {
        let combatant: Combatant
        let health: Int
        let maxHealth: Int
        let activeEffectSummaries: [TrinketCore.EffectSummary]
    }

    struct ReadModel {
        let hero: Combatant
        let companion: Combatant
        let enemy: Combatant
        let hand: [BattleCard]
        let turnCount: Int
        let earnedGold: Int
        let isBattleOver: Bool
        let isPartyDefeated: Bool
        let events: [ActionEvent]
        let log: [LogEntry]
        let healthByCombatantID: [String: Int]
        let modifiersByCombatantID: [String: CombatModifierProfile]
    }

    struct VictoryInput {
        let earnedGold: Int
        let heroName: String
        let companionName: String
    }

    private var state: BattleState?
    private(set) var configurationID: UUID?

    var hasState: Bool {
        state != nil
    }

    var phase: BattlePhase? {
        state?.phase
    }

    var outcome: BattleSimulationOutcome? {
        BattleSimBridge.outcome(for: state)
    }

    var isBattleOver: Bool {
        state?.isBattleOver ?? false
    }

    var isHeroAlive: Bool {
        state?.isHeroAlive ?? false
    }

    var isCompanionAlive: Bool {
        state?.isCompanionAlive ?? false
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

    func makePreparedRun(from configuration: BattleRunConfiguration) -> PreparedRun {
        PreparedRun(
            state: BattleSimBridge.makeBattleState(from: configuration),
            configurationID: configuration.id
        )
    }

    func activate(_ preparedRun: PreparedRun) {
        state = preparedRun.state
        configurationID = preparedRun.configurationID
    }

    func reset(from configuration: BattleRunConfiguration) {
        state = BattleSimBridge.makeBattleState(from: configuration)
        configurationID = configuration.id
    }

    func clear() {
        state = nil
        configurationID = nil
    }

    func presentationSnapshot() -> BattlePresentationSnapshot? {
        guard let state,
              let configurationID
        else { return nil }
        return BattlePresentationSnapshot(configurationID: configurationID, state: state)
    }

    func openingHandArtworkNames(for preparedRun: PreparedRun) -> [String] {
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
}
