import Foundation
import TrinketContent
import TrinketCore

/// Mutation surface passed to rule engines. Same storage as `BattleState`.
public typealias BattleEngineContext = BattleState

/// Top-level battle facade: UI calls `playCard` / `endTurn`; rule engines mutate
/// via `package` APIs in `BattleState+*.swift`. Put effect rules in
/// `EffectHandlers/`, shared math in existing engines, and never add
/// catalog-specific branches here. See `Docs/AgentContext/battle.md`.
///
/// `events` is the append-only stream for the whole battle; method return
/// values are the delta from that call only.
public struct BattleState {
    public let hero: Combatant
    public let companion: Combatant
    public let enemy: Combatant

    /// Seed used to initialize battle RNG. Fixed for the battle's lifetime.
    public let rngSeed: UInt64

    /// When `false`, no log cache is allocated or updated during the battle.
    public let tracksLog: Bool

    /// When `false`, action events are not retained on `events` (still returned from step APIs).
    /// Use for bulk simulation to avoid unbounded allocation.
    public let tracksEvents: Bool

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
    public let companionModifiers: CombatModifierProfile
    public let enemyModifiers: CombatModifierProfile
    public var actionCount: Int
    public var hasLoggedDefeat: Bool
    public var hasLoggedPartyDefeat: Bool

    public var phase: BattlePhase
    public var hand: BattleHand
    /// Cards drawn while the hand was full; promote FIFO when a slot frees.
    public var handBuffer: BattleHandBuffer
    public var heroDeck: CombatDeck
    public var companionDeck: CombatDeck
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
        companionModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile,
        actionCount: Int = 0,
        hasLoggedDefeat: Bool = false,
        hasLoggedPartyDefeat: Bool = false,
        phase: BattlePhase = .playerTurn,
        hand: BattleHand = BattleHand(),
        handBuffer: BattleHandBuffer = BattleHandBuffer(),
        heroDeck: CombatDeck = CombatDeck(),
        companionDeck: CombatDeck = CombatDeck(),
        nextCardID: Int = 0,
        ownersSkippingThisPlayerTurn: Set<BattleParticipant> = [],
        tracksLog: Bool = false,
        tracksEvents: Bool = true
    ) {
        hero = roster.hero.combatant
        companion = roster.companion.combatant
        enemy = roster.enemy.combatant
        rngSeed = rng.seed
        self.tracksLog = tracksLog
        self.tracksEvents = tracksEvents
        cachedMatchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)
        self.roster = roster
        self.rng = rng
        self.tickCount = tickCount
        self.nextEffectID = nextEffectID
        self.nextEventID = nextEventID
        self.events = events
        self.gold = gold
        self.initialGold = initialGold
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.enemyModifiers = enemyModifiers
        self.actionCount = actionCount
        self.hasLoggedDefeat = hasLoggedDefeat
        self.hasLoggedPartyDefeat = hasLoggedPartyDefeat
        self.phase = phase
        self.hand = hand
        self.handBuffer = handBuffer
        self.heroDeck = heroDeck
        self.companionDeck = companionDeck
        self.nextCardID = nextCardID
        self.ownersSkippingThisPlayerTurn = ownersSkippingThisPlayerTurn
    }

    public init(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activeCompanionEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64? = nil,
        tracksLog: Bool = true,
        tracksEvents: Bool = true,
        dealOpeningHand: Bool = true
    ) {
        self.hero = hero
        self.companion = companion
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        self.enemy = resolvedEnemy
        self.tracksLog = tracksLog
        self.tracksEvents = tracksEvents
        cachedMatchup = BattleMatchup(hero: hero, companion: companion, enemy: resolvedEnemy)

        let seed = rngSeed ?? Self.defaultRNGSeed
        self.rngSeed = seed

        roster = BattleRoster(
            hero: CombatantRuntime(
                combatant: hero,
                initialActiveEffects: activeHeroEffects,
                maximumHealthBonus: heroModifiers.maximumHealthBonus,
                maximumManaBonus: heroModifiers.maximumManaBonus
            ),
            companion: CombatantRuntime(
                combatant: companion,
                initialActiveEffects: activeCompanionEffects,
                maximumHealthBonus: companionModifiers.maximumHealthBonus,
                maximumManaBonus: companionModifiers.maximumManaBonus
            ),
            enemy: CombatantRuntime(combatant: resolvedEnemy, initialActiveEffects: activeEnemyEffects)
        )
        let maxExistingEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activeCompanionEffects.map(\.id).max() ?? 0
        )
        nextEffectID = maxExistingEffectID + 1
        rng = SeededRandomNumberGenerator(seed: seed)
        tickCount = 0
        nextEventID = 0
        events = []
        gold = initialGold
        self.initialGold = initialGold
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.enemyModifiers = enemyModifiers
        actionCount = 0
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false
        phase = .playerTurn
        hand = BattleHand()
        handBuffer = BattleHandBuffer()
        heroDeck = CombatDeck()
        companionDeck = CombatDeck()
        nextCardID = 0
        ownersSkippingThisPlayerTurn = []

        _ = appendMilestone(.battleStarted, matchup: cachedMatchup)

        if dealOpeningHand {
            BattleCardCombatEngine.bootstrapDecksAndOpeningHand(context: &self)
        } else {
            BattleCardCombatEngine.bootstrapDecks(context: &self)
        }

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

    /// Fills the opening hand in one step (tests / headless). Prefer paced
    /// `drawNextOpeningHandCard` when the UI should animate each draw.
    public mutating func drawOpeningHand(rebuildLog: Bool = true) {
        BattleCardCombatEngine.drawOpeningHand(context: &self)
        finishMutation(rebuildLog: rebuildLog)
    }

    /// Draws a single opening-hand card. Returns `false` when no further draw is possible.
    @discardableResult
    public mutating func drawNextOpeningHandCard(rebuildLog: Bool = true) -> Bool {
        let drew = BattleCardCombatEngine.drawNextOpeningHandCard(context: &self)
        if drew {
            finishMutation(rebuildLog: rebuildLog)
        }
        return drew
    }

    /// Recomputes which party owners skip card play this turn (call after paced opening deal).
    public mutating func finalizeOpeningHand() {
        BattleCardCombatEngine.finalizeOpeningHand(context: &self)
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
