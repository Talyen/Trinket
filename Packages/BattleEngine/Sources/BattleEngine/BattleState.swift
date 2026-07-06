import Foundation
import TrinketCore
import TrinketContent

/// The state of a single battle. `BattleState` is the top-level facade
/// drivers (UI, simulation) interact with: it exposes per-combatant
/// read-only views and the single mutable entry point `advanceOneStep()`
/// that ticks the simulation forward by one step.
///
/// **Public surface (read-only views):**
/// - Combatant definitions: `hero`, `pet`, `enemy`
/// - Per-combatant state: `health(of:)`, `mana(of:)`, `maxMana(of:)`,
///   `maxHealth(of:)`, `actionCount(of:)`, `activeEffects(of:)`,
///   `effectSummaries(of:)`
/// - Global state: `tickCount`, `actionCount`, `events`, `gold`, `earnedGold`,
///   `rngSeed`
/// - Derived: `log` (empty when `tracksLog` is `false`)
/// - Booleans: `isHeroAlive`, `isPetAlive`, `isEnemyDefeated`,
///   `isPartyDefeated`, `isBattleOver`
/// - AI helper: `enemyAttackTarget`
///
/// **Public surface (mutations):**
/// - `init(...)` — construct a battle
/// - `advanceOneStep() -> BattleStep` — drive the simulation by one tick
///
/// **Event semantics:**
/// - `events` is the cumulative append-only stream for the whole battle.
/// - `BattleStep.events` is the delta emitted during that step only.
/// - Metrics and per-tick consumers should use `BattleStep.events`; replay
///   and log projection use `events`.
///
/// **Internal:**
/// - All mutable battle state lives in `BattleMutableStore` (`store`), mutated
///   in place by rule engines during each step
/// - Optional `BattleLogProjection` holds the cached combat log when
///   `tracksLog` is enabled
/// - Turn orchestration lives in `BattleLoopEngine`
/// - Effect application rules live on the `BattleEffectHandler` structs in
///   `EffectHandlers.swift`
public struct BattleState {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    /// Seed used to initialize battle RNG. Fixed for the battle's lifetime.
    public let rngSeed: UInt64

    /// When `false`, no log cache is allocated or updated during the battle.
    public let tracksLog: Bool

    /// All mutable battle state. Rule engines mutate this in place each step.
    var store: BattleMutableStore

    private let cachedMatchup: BattleMatchup
    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

    public init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64? = nil,
        tracksLog: Bool = true
    ) {
        self.hero = hero
        self.pet = pet
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        self.enemy = resolvedEnemy
        self.tracksLog = tracksLog
        cachedMatchup = BattleMatchup(hero: hero, pet: pet, enemy: resolvedEnemy)

        let seed = rngSeed ?? Self.defaultRNGSeed
        self.rngSeed = seed

        store = BattleMutableStore.make(
            hero: hero,
            pet: pet,
            enemy: resolvedEnemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activePetEffects: activePetEffects,
            initialGold: initialGold,
            heroModifiers: heroModifiers,
            petModifiers: petModifiers,
            enemyModifiers: enemyModifiers,
            rngSeed: seed
        )

        _ = store.appendMilestone(.battleStarted, matchup: cachedMatchup)

        if tracksLog {
            var projection = BattleLogProjection()
            projection.sync(events: store.events, matchup: cachedMatchup)
            logProjection = projection
        }
    }

    // MARK: - Global mutable state (read-through from store)

    public var tickCount: Int {
        store.tickCount
    }

    public var actionCount: Int {
        store.actionCount
    }

    public var events: [ActionEvent] {
        store.events
    }

    public var gold: Int {
        store.gold
    }

    /// Cached combat log when `tracksLog` is `true`; otherwise empty.
    public var log: [LogEntry] {
        logProjection?.entries ?? []
    }

    // MARK: - Per-combatant state accessors

    public var earnedGold: Int {
        store.gold - store.initialGold
    }

    public var isEnemyDefeated: Bool {
        store.roster.isEnemyDefeated
    }

    public var isHeroAlive: Bool {
        store.roster.hero.isAlive
    }

    public var isPetAlive: Bool {
        store.roster.pet.isAlive
    }

    public var isPartyDefeated: Bool {
        store.roster.isPartyDefeated
    }

    public var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    public var enemyAttackTarget: Combatant {
        store.roster.enemyAttackTarget
    }

    public var matchup: BattleMatchup {
        cachedMatchup
    }

    public func health(of combatant: Combatant) -> Int {
        store.roster.health(for: combatant)
    }

    public func maxHealth(of combatant: Combatant) -> Int {
        store.roster.maxHealth(for: combatant)
    }

    public func mana(of combatant: Combatant) -> Int {
        store.roster.runtime(for: combatant)?.currentMana ?? 0
    }

    public func maxMana(of combatant: Combatant) -> Int {
        store.roster.runtime(for: combatant)?.maxMana ?? 0
    }

    public func actionCount(of combatant: Combatant) -> Int {
        store.roster.runtime(for: combatant)?.actionCount ?? 0
    }

    public func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        store.roster.activeEffects(for: combatant)
    }

    public func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    // MARK: - Modifier profile

    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        store.modifiers(for: combatantID)
    }

    // MARK: - Engine context

    /// Runs `body` against the battle store in place, then refreshes the log
    /// when `tracksLog` is enabled.
    package mutating func withEngineContext<R>(_ body: (inout BattleEngineContext) throws -> R) rethrows -> R {
        let result = try body(&store)
        finishMutation(rebuildLog: true)
        return result
    }

    /// Test helper for seeding active effects without exposing `BattleRoster`.
    mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        store.roster.setActiveEffects(effects, for: combatant)
    }

    // MARK: - Turn loop

    @discardableResult
    public mutating func advanceOneStep(rebuildLog: Bool = true) -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        let step = BattleLoopEngine.advanceOneStep(matchup: cachedMatchup, context: &store)
        finishMutation(rebuildLog: rebuildLog)
        return step
    }

    /// Brings `log` in sync with `events`. Creates the projection on demand when
    /// `tracksLog` was disabled during auto-ticks.
    public mutating func syncLog() {
        if logProjection == nil {
            var projection = BattleLogProjection()
            projection.rebuildFromScratch(events: store.events, matchup: cachedMatchup)
            logProjection = projection
        } else {
            logProjection?.sync(events: store.events, matchup: cachedMatchup)
        }
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: store.events, matchup: cachedMatchup)
    }
}
