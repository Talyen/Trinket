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
/// - Derived: `log`
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
/// - Per-combatant mutable state lives on `BattleRoster` (via three
///   `CombatantRuntime`s), accessed only through `BattleEngineContext` during
///   rule dispatch
/// - Turn orchestration lives in `BattleLoopEngine`
/// - Effect application rules live on the `BattleEffectHandler` structs in
///   `EffectHandlers.swift`
/// - Combat log lines are derived from the event stream by `BattleLogReducer`
public struct BattleState {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    /// Seed used to initialize battle RNG. Fixed for the battle's lifetime.
    public let rngSeed: UInt64

    // MARK: - Global mutable state

    public private(set) var tickCount: Int
    public private(set) var actionCount: Int
    public private(set) var events: [ActionEvent]
    public private(set) var gold: Int

    var roster: BattleRoster
    var nextEventID: Int
    var nextEffectID: Int
    var rng: SeededRandomNumberGenerator
    var hasLoggedDefeat: Bool
    var hasLoggedPartyDefeat: Bool
    let combatBuild: BattleCombatBuild
    private let initialGold: Int

    /// Cached combat log. Rebuilt incrementally after mutations; callers that
    /// defer rebuilds should call `syncLog()` before reading.
    public private(set) var log: [LogEntry] = []

    /// Number of trailing `events` already reflected in `log`.
    private var loggedEventCount: Int = 0

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
        rngSeed: UInt64? = nil
    ) {
        self.hero = hero
        self.pet = pet
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        self.enemy = resolvedEnemy
        combatBuild = BattleCombatBuild(
            hero: hero,
            pet: pet,
            heroModifiers: heroModifiers,
            petModifiers: petModifiers
        )

        let seed = rngSeed ?? UInt64.random(in: UInt64.min ... UInt64.max)
        self.rngSeed = seed
        rng = SeededRandomNumberGenerator(seed: seed)

        tickCount = 0
        actionCount = 0

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

        nextEventID = 0
        nextEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activePetEffects.map(\.id).max() ?? 0
        )
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false

        self.initialGold = initialGold
        gold = initialGold

        events = []
        var context = makeEngineContext()
        _ = context.appendMilestone(.battleStarted, matchup: matchup)
        applyEngineContext(context)
        rebuildLogFromScratch()
    }

    // MARK: - Per-combatant state accessors

    public var earnedGold: Int {
        gold - initialGold
    }

    public var isEnemyDefeated: Bool {
        roster.isEnemyDefeated
    }

    public var isHeroAlive: Bool {
        roster.hero.isAlive
    }

    public var isPetAlive: Bool {
        roster.pet.isAlive
    }

    public var isPartyDefeated: Bool {
        roster.isPartyDefeated
    }

    public var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    public var enemyAttackTarget: Combatant {
        roster.enemyAttackTarget
    }

    public var matchup: BattleMatchup {
        BattleMatchup(hero: hero, pet: pet, enemy: enemy)
    }

    public func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    public func maxHealth(of combatant: Combatant) -> Int {
        roster.maxHealth(for: combatant)
    }

    public func mana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.currentMana ?? 0
    }

    public func maxMana(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.maxMana ?? 0
    }

    public func actionCount(of combatant: Combatant) -> Int {
        roster.runtime(for: combatant)?.actionCount ?? 0
    }

    public func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    public func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    // MARK: - Modifier profile

    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        combatBuild.modifiers(for: combatantID)
    }

    // MARK: - Engine context

    mutating func makeEngineContext() -> BattleEngineContext {
        BattleEngineContext(
            roster: roster,
            rng: rng,
            tickCount: tickCount,
            nextEffectID: nextEffectID,
            nextEventID: nextEventID,
            events: events,
            gold: gold,
            build: combatBuild,
            actionCount: actionCount,
            hasLoggedDefeat: hasLoggedDefeat,
            hasLoggedPartyDefeat: hasLoggedPartyDefeat
        )
    }

    mutating func applyEngineContext(_ context: BattleEngineContext) {
        roster = context.roster
        rng = context.rng
        tickCount = context.tickCount
        nextEffectID = context.nextEffectID
        nextEventID = context.nextEventID
        events = context.events
        gold = context.gold
        actionCount = context.actionCount
        hasLoggedDefeat = context.hasLoggedDefeat
        hasLoggedPartyDefeat = context.hasLoggedPartyDefeat
    }

    /// Copies the relevant mutable fields into a `BattleEngineContext`, runs
    /// `body`, then copies the mutated context back into `self`.
    package mutating func withEngineContext<R>(_ body: (inout BattleEngineContext) throws -> R) rethrows -> R {
        var context = makeEngineContext()
        let result = try body(&context)
        applyEngineContext(context)
        finishMutation(rebuildLog: true)
        return result
    }

    /// Test helper for seeding active effects without exposing `BattleRoster`.
    mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    // MARK: - Pipeline forwarding (package — tests and in-package rule code only)

    package mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        withEngineContext { context in
            CombatPipeline.applyDamage(
                amount,
                to: combatant,
                damageKeyword: damageKeyword,
                sourceActorID: sourceActorID,
                applyStatBonus: applyStatBonus,
                applyItemBonus: applyItemBonus,
                applyDodge: applyDodge,
                in: &context
            )
        }
    }

    package mutating func applyHeal(_ amount: Int, to combatant: Combatant, sourceActorID: String? = nil) {
        withEngineContext { context in
            CombatPipeline.applyHeal(amount, to: combatant, sourceActorID: sourceActorID, in: &context)
        }
    }

    package mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        withEngineContext { context in
            CombatPipeline.applyLeechFromDamage(damage, sourceActorID: sourceActorID, in: &context)
        }
    }

    // MARK: - Turn loop

    @discardableResult
    public mutating func advanceOneStep(rebuildLog: Bool = true) -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        var context = makeEngineContext()
        let step = BattleLoopEngine.advanceOneStep(matchup: matchup, context: &context)
        applyEngineContext(context)
        finishMutation(rebuildLog: rebuildLog)
        return step
    }

    /// Brings `log` in sync with `events`. No-op when already current.
    public mutating func syncLog() {
        appendLogEntries()
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        if rebuildLog {
            appendLogEntries()
        }
    }

    private mutating func appendLogEntries() {
        guard loggedEventCount < events.count else {
            if loggedEventCount > events.count {
                rebuildLogFromScratch()
            }
            return
        }

        log.append(contentsOf: BattleLogReducer.entries(
            from: events,
            startingAt: loggedEventCount,
            matchup: matchup
        ))
        loggedEventCount = events.count
    }

    private mutating func rebuildLogFromScratch() {
        log = BattleLogReducer.entries(from: events, matchup: matchup)
        loggedEventCount = events.count
    }
}
