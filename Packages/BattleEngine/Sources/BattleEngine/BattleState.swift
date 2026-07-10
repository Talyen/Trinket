import Foundation
import TrinketContent
import TrinketCore

/// Mutation surface passed to rule engines. Same storage as `BattleState`.
public typealias BattleEngineContext = BattleState

/// The state of a single battle. `BattleState` is the top-level facade
/// drivers (UI) interact with: it exposes per-combatant read-only views and
/// the mutable entry points `playCard(cardID:)` / `endTurn()` that drive
/// turn-based card combat.
///
/// **Public surface (read-only views):**
/// - Combatant definitions: `hero`, `pet`, `enemy`
/// - Per-combatant state: `health(of:)`, `mana(of:)`, `maxMana(of:)`,
///   `maxHealth(of:)`, `actionCount(of:)`, `activeEffects(of:)`,
///   `effectSummaries(of:)`, `modifiers(for:)`
/// - Global state: `tickCount` (round index), `actionCount`, `events`, `gold`,
///   `earnedGold`, `rngSeed`, `phase`, `hand`
/// - Derived: `log` (empty when `tracksLog` is `false`)
/// - Booleans: `isHeroAlive`, `isPetAlive`, `isEnemyDefeated`,
///   `isPartyDefeated`, `isBattleOver`
/// - AI helper: `enemyAttackTarget`
///
/// **Public surface (mutations):**
/// - `init(...)` — construct a battle (opens with 2 Hero + 2 Pet cards)
/// - `playCard(cardID:)` / `endTurn()` — drive card combat
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
/// - Method return values hold the delta emitted during that call only.
/// - Metrics consumers should use the returned delta; replay and log
///   projection use `events`.
///
/// **Internal:**
/// - Rule engines mutate battle state in place during each step
/// - Optional `BattleLogProjection` holds the cached combat log when
///   `tracksLog` is enabled
/// - Turn orchestration lives in `BattleCardCombatEngine`
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
    /// Round index. Advances once per full round (player turn + enemy turn + effect tick).
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

    public var phase: BattlePhase
    public var hand: BattleHand
    public var heroDeck: CombatDeck
    public var petDeck: CombatDeck
    public var nextCardID: Int
    /// Party owners whose cards are unplayable this player turn due to control skip.
    public var ownersSkippingThisPlayerTurn: Set<BattleParticipant>

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
        hasLoggedPartyDefeat: Bool = false,
        phase: BattlePhase = .playerTurn,
        hand: BattleHand = BattleHand(),
        heroDeck: CombatDeck = CombatDeck(),
        petDeck: CombatDeck = CombatDeck(),
        nextCardID: Int = 0,
        ownersSkippingThisPlayerTurn: Set<BattleParticipant> = []
    ) {
        hero = roster.hero.combatant
        pet = roster.pet.combatant
        enemy = roster.enemy.combatant
        rngSeed = rng.seed
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
        self.phase = phase
        self.hand = hand
        self.heroDeck = heroDeck
        self.petDeck = petDeck
        self.nextCardID = nextCardID
        self.ownersSkippingThisPlayerTurn = ownersSkippingThisPlayerTurn
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
        phase = .playerTurn
        hand = BattleHand()
        heroDeck = CombatDeck()
        petDeck = CombatDeck()
        nextCardID = 0
        ownersSkippingThisPlayerTurn = []

        _ = appendMilestone(.battleStarted, matchup: cachedMatchup)

        BattleCardCombatEngine.bootstrapDecksAndOpeningHand(context: &self)

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

    // MARK: - Card combat

    @discardableResult
    public mutating func playCard(cardID: Int, rebuildLog: Bool = true) throws -> [ActionEvent] {
        guard !isBattleOver else { throw BattlePlayError.battleOver }
        // Events are already appended via `nextEvent` during resolution; return value is the delta.
        let events = try BattleCardCombatEngine.playCard(
            cardID: cardID,
            matchup: cachedMatchup,
            context: &self
        )
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func endTurn(rebuildLog: Bool = true) -> [ActionEvent] {
        guard !isBattleOver else { return [] }
        let events = BattleCardCombatEngine.endTurn(matchup: cachedMatchup, context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    public func isCardPlayable(_ card: BattleCard) -> Bool {
        BattleCardCombatEngine.isCardPlayable(card, in: self)
    }

    /// Brings `log` in sync with `events`. Creates the projection on demand when
    /// `tracksLog` was disabled during play.
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
