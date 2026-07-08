import Foundation
import TrinketContent
import TrinketCore

/// Mutation surface passed to rule engines. Same storage as `BattleState`.
///
/// `tickCount` is advanced by `BattleLoopEngine.advanceOneStep` at the start
/// of each step; callers should not increment it manually.
public typealias BattleEngineContext = BattleState

/// The state of a single battle. `BattleState` is the top-level facade
/// drivers (UI, simulation) interact with: it exposes per-combatant
/// read-only views and the single mutable entry point `advanceOneStep()`
/// that ticks the simulation forward by one step.
///
/// **Public surface (read-only views):**
/// - Combatant definitions: `hero`, `pet`, `enemy`
/// - Per-combatant state: `health(of:)`, `mana(of:)`, `maxMana(of:)`,
///   `maxHealth(of:)`, `actionCount(of:)`, `activeEffects(of:)`,
///   `effectSummaries(of:)`, `modifiers(for:)`
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
/// - `syncLog()` / `releaseLogProjection()` — log cache lifecycle
///
/// **Engine-facing mutations** (`package`, in `BattleState+*.swift`):
/// damage/heal/DoT/control, effect append, gold/mana, event factories.
/// App and feature code must not call these — extend an `*Engine` or handler.
///
/// **Where to put new combat code:**
/// 1. Effect-specific rules → `EffectHandlers/`
/// 2. Shared combat math → existing `*Engine` / `DamagePipeline` / applicator
/// 3. Shared mutation plumbing used by multiple engines → `BattleState+*.swift`
/// 4. Never add catalog-specific branching to `BattleState`
///
/// **Event semantics:**
/// - `events` is the cumulative append-only stream for the whole battle.
/// - `BattleStep.events` is the delta emitted during that step only.
/// - Metrics and per-tick consumers should use `BattleStep.events`; replay
///   and log projection use `events`.
///
/// **Internal:**
/// - Rule engines mutate battle state in place during each step
/// - Optional `BattleLogProjection` holds the cached combat log when
///   `tracksLog` is enabled
/// - Turn orchestration lives in `BattleLoopEngine`
public struct BattleState {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    /// Seed used to initialize battle RNG. Fixed for the battle's lifetime.
    public let rngSeed: UInt64

    /// When `false`, no log cache is allocated or updated during the battle.
    public let tracksLog: Bool

    public var roster: BattleRoster
    public var rng: SeededRandomNumberGenerator
    public var tickCount: Int
    public var nextEffectID: Int
    public var nextEventID: Int
    public var events: [ActionEvent]
    public var gold: Int
    public let initialGold: Int
    public let heroModifiers: CombatModifierProfile
    public let petModifiers: CombatModifierProfile
    public let enemyModifiers: CombatModifierProfile
    public var actionCount: Int
    public var hasLoggedDefeat: Bool
    public var hasLoggedPartyDefeat: Bool

    /// Matchup snapshot; module-internal so `BattleState+*.swift` can read it.
    let cachedMatchup: BattleMatchup
    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

    public init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        tickCount: Int = 0,
        nextEffectID: Int,
        nextEventID: Int,
        events: [ActionEvent],
        gold: Int,
        initialGold: Int,
        heroModifiers: CombatModifierProfile,
        petModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile,
        actionCount: Int = 0,
        hasLoggedDefeat: Bool = false,
        hasLoggedPartyDefeat: Bool = false
    ) {
        hero = roster.hero.combatant
        pet = roster.pet.combatant
        enemy = roster.enemy.combatant
        rngSeed = 0
        tracksLog = false
        cachedMatchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)
        self.roster = roster
        self.rng = rng
        self.tickCount = tickCount
        self.nextEffectID = nextEffectID
        self.nextEventID = nextEventID
        self.events = events
        self.gold = gold
        self.initialGold = initialGold
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
        self.actionCount = actionCount
        self.hasLoggedDefeat = hasLoggedDefeat
        self.hasLoggedPartyDefeat = hasLoggedPartyDefeat
    }

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

        roster = BattleRoster(
            hero: CombatantRuntime(
                combatant: hero,
                initialActiveEffects: activeHeroEffects,
                maximumHealthBonus: heroModifiers.maximumHealthBonus,
                maximumManaBonus: heroModifiers.maximumManaBonus
            ),
            pet: CombatantRuntime(
                combatant: pet,
                initialActiveEffects: activePetEffects,
                maximumHealthBonus: petModifiers.maximumHealthBonus,
                maximumManaBonus: petModifiers.maximumManaBonus
            ),
            enemy: CombatantRuntime(combatant: resolvedEnemy, initialActiveEffects: activeEnemyEffects)
        )
        let maxExistingEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activePetEffects.map(\.id).max() ?? 0
        )
        nextEffectID = maxExistingEffectID + 1
        rng = SeededRandomNumberGenerator(seed: seed)
        tickCount = 0
        nextEventID = 0
        events = []
        gold = initialGold
        self.initialGold = initialGold
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
        actionCount = 0
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false

        _ = appendMilestone(.battleStarted, matchup: cachedMatchup)

        if tracksLog {
            var projection = BattleLogProjection()
            projection.sync(events: events, matchup: cachedMatchup)
            logProjection = projection
        }
    }

    /// Cached combat log when `tracksLog` is `true`; otherwise empty.
    public var log: [LogEntry] {
        logProjection?.entries ?? []
    }

    // MARK: - Engine context

    /// Runs `body` against the battle state in place, then refreshes the log
    /// when `tracksLog` is enabled.
    package mutating func withEngineContext<R>(_ body: (inout BattleEngineContext) throws -> R) rethrows -> R {
        let result = try body(&self)
        finishMutation(rebuildLog: true)
        return result
    }

    /// Test helper for seeding active effects without exposing `BattleRoster`.
    package mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    // MARK: - Turn loop

    @discardableResult
    public mutating func advanceOneStep(rebuildLog: Bool = true) -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        let step = BattleLoopEngine.advanceOneStep(matchup: cachedMatchup, context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return step
    }

    /// Brings `log` in sync with `events`. Creates the projection on demand when
    /// `tracksLog` was disabled during auto-ticks.
    public mutating func syncLog() {
        if logProjection == nil {
            var projection = BattleLogProjection()
            projection.rebuildFromScratch(events: events, matchup: cachedMatchup)
            logProjection = projection
        } else {
            logProjection?.sync(events: events, matchup: cachedMatchup)
        }
    }

    /// Drops the cached combat-log projection to reclaim memory. Call `syncLog()` to rebuild.
    public mutating func releaseLogProjection() {
        logProjection = nil
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events, matchup: cachedMatchup)
    }
}
