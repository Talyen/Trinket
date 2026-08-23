import Foundation
import TrinketContent
import TrinketCore

/// Once-per-action or once-per-battle talent gate keyed by actor.
public struct TalentActionGuardKey: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case spendCocoon
        case spendOvercharge
        case spendCleanse
        case spendChaosRift
        case spendFreeze
        case darkRecovery
        case arcaneBurst
        case surpriseStrike
        case seismicRoar
        case endlessLegion
    }

    public var kind: Kind
    public var actorID: String

    public init(kind: Kind, actorID: String) {
        self.kind = kind
        self.actorID = actorID
    }
}

/// Top-level battle facade: UI calls `playCard` / `endTurn`; rule engines mutate
/// via `package` APIs in `BattleState+*.swift`. Put effect rules in
/// `EffectHandlers/`, shared math in existing engines, and never add
/// catalog-specific branches here. See `Docs/AgentContext/battle.md`.
///
/// `events` is the append-only stream for the whole battle; method return
/// values are the delta from that call only.
public struct BattleState {
    /// Seed used to initialize battle RNG. Fixed for the battle's lifetime.
    public let rngSeed: UInt64

    /// When `false`, no log cache is allocated or updated during the battle.
    public let tracksLog: Bool

    /// When `false`, action events are not retained on `events` (still returned from step APIs).
    /// Use for bulk simulation to avoid unbounded allocation.
    public let tracksEvents: Bool

    /// When `false`, authored combat magnitudes skip hidden `FightPacing` scaling.
    /// Shipping battles leave this `true`.
    public var appliesFightPacing: Bool

    public var roster: BattleRoster
    public var rng: SeededRandomNumberGenerator
    /// Round index. Advances once per full round (player turn + enemy turn + effect pass).
    public var turnCount: Int
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
    /// Set when the enemy reaches 0 Health so defeat talents can require a critical killing blow.
    public var lastEnemyDefeatWasCritical: Bool

    public var phase: BattlePhase
    public var hand: BattleHand
    /// Cards drawn while the hand was full; promote FIFO when a slot frees.
    public var handBuffer: BattleHandBuffer
    public var heroDeck: CombatDeck
    public var companionDeck: CombatDeck
    public var nextCardID: Int
    /// Party owners whose cards are unplayable this player turn due to control skip.
    public var ownersSkippingThisPlayerTurn: Set<BattleParticipant>
    public var cardsPlayedThisTurn: [BattleParticipant: Int]
    public var skillCardsPlayedThisTurn: [BattleParticipant: Int]
    public var freezeCardsPlayedThisTurn: [BattleParticipant: Int]
    public var burnManaRestoredThisTurn: [String: Int]
    public var spendManaDrawOwnersThisTurn: Set<BattleParticipant>
    public var healthLossDrawOwnersThisTurn: Set<BattleParticipant>
    public var goldDrawOwnersThisTurn: Set<BattleParticipant>
    public var additionalControlSkipsByCombatantID: [String: Int]
    public var isResolvingTalentReaction: Bool
    public var isResolvingDoTDetonation: Bool
    public var criticalGoldActionByActorID: [String: Int]
    /// Once-per-action guards for combatant talent thresholds (Mana Cocoon, Overcharge, Chaos Rift).
    public var talentActionGuardByActorID: [TalentActionGuardKey: Int]
    /// Spell Echo: combatants who already echoed their first Skill this battle.
    public var skillEchoOwnersThisBattle: Set<String>
    /// Nested damage/heal reaction depth. Values above 1 skip extra talent reactions.
    public var talentReactionDepth: Int
    /// Nested DoT application depth to prevent infinite cascading trigger loops.
    public var dotRecursionDepth: Int
    /// True while Arcane Burst is auto-playing a card (blocks re-entry).
    public var isResolvingAutoPlayCard: Bool
    /// Nested `drawAndPlayCards` auto-play depth. Caps runaway chains.
    public var drawAndPlayDepth: Int = 0
    /// Maximum nested auto-play depth; further draw-and-play effects skip drawing.
    public static let maxDrawAndPlayDepth = 8
    /// Authored faction of the enemy in this battle (talent conditions such as Bane of Evil).
    public let enemyFaction: EnemyFaction

    /// Party-wide triggers from living allies. Dead companions do not keep auras.
    public var partyTriggers: CombatTraitTriggers {
        CombatTriggerEngine.livingPartyTriggers(in: self)
    }

    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

    /// Full-state init for engine tests and simulation snapshots; production
    /// callers use the new-battle convenience init below.
    package init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        turnCount: Int = 0,
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
        lastEnemyDefeatWasCritical: Bool = false,
        phase: BattlePhase = .playerTurn,
        hand: BattleHand = BattleHand(),
        handBuffer: BattleHandBuffer = BattleHandBuffer(),
        heroDeck: CombatDeck = CombatDeck(),
        companionDeck: CombatDeck = CombatDeck(),
        nextCardID: Int = 0,
        ownersSkippingThisPlayerTurn: Set<BattleParticipant> = [],
        cardsPlayedThisTurn: [BattleParticipant: Int] = [:],
        skillCardsPlayedThisTurn: [BattleParticipant: Int] = [:],
        freezeCardsPlayedThisTurn: [BattleParticipant: Int] = [:],
        burnManaRestoredThisTurn: [String: Int] = [:],
        spendManaDrawOwnersThisTurn: Set<BattleParticipant> = [],
        healthLossDrawOwnersThisTurn: Set<BattleParticipant> = [],
        goldDrawOwnersThisTurn: Set<BattleParticipant> = [],
        additionalControlSkipsByCombatantID: [String: Int] = [:],
        isResolvingTalentReaction: Bool = false,
        isResolvingDoTDetonation: Bool = false,
        criticalGoldActionByActorID: [String: Int] = [:],
        talentActionGuardByActorID: [TalentActionGuardKey: Int] = [:],
        skillEchoOwnersThisBattle: Set<String> = [],
        talentReactionDepth: Int = 0,
        dotRecursionDepth: Int = 0,
        isResolvingAutoPlayCard: Bool = false,
        drawAndPlayDepth: Int = 0,
        enemyFaction: EnemyFaction = .mortal,
        tracksLog: Bool = false,
        tracksEvents: Bool = true,
        appliesFightPacing: Bool = true
    ) {
        rngSeed = rng.seed
        self.tracksLog = tracksLog
        self.tracksEvents = tracksEvents
        self.appliesFightPacing = appliesFightPacing
        self.roster = roster
        self.rng = rng
        self.turnCount = turnCount
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
        self.lastEnemyDefeatWasCritical = lastEnemyDefeatWasCritical
        self.phase = phase
        self.hand = hand
        self.handBuffer = handBuffer
        self.heroDeck = heroDeck
        self.companionDeck = companionDeck
        self.nextCardID = nextCardID
        self.ownersSkippingThisPlayerTurn = ownersSkippingThisPlayerTurn
        self.cardsPlayedThisTurn = cardsPlayedThisTurn
        self.skillCardsPlayedThisTurn = skillCardsPlayedThisTurn
        self.freezeCardsPlayedThisTurn = freezeCardsPlayedThisTurn
        self.burnManaRestoredThisTurn = burnManaRestoredThisTurn
        self.spendManaDrawOwnersThisTurn = spendManaDrawOwnersThisTurn
        self.healthLossDrawOwnersThisTurn = healthLossDrawOwnersThisTurn
        self.goldDrawOwnersThisTurn = goldDrawOwnersThisTurn
        self.additionalControlSkipsByCombatantID = additionalControlSkipsByCombatantID
        self.isResolvingTalentReaction = isResolvingTalentReaction
        self.isResolvingDoTDetonation = isResolvingDoTDetonation
        self.criticalGoldActionByActorID = criticalGoldActionByActorID
        self.talentActionGuardByActorID = talentActionGuardByActorID
        self.skillEchoOwnersThisBattle = skillEchoOwnersThisBattle
        self.talentReactionDepth = talentReactionDepth
        self.dotRecursionDepth = dotRecursionDepth
        self.isResolvingAutoPlayCard = isResolvingAutoPlayCard
        self.drawAndPlayDepth = drawAndPlayDepth

        self.enemyFaction = enemyFaction
    }

    /// New-battle convenience init. Builds the roster, then delegates to the
    /// full-state init so field defaults stay in one place.
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
        heroStartingHealth: Int? = nil,
        companionStartingHealth: Int? = nil,
        enemyFaction: EnemyFaction = .mortal,
        rngSeed: UInt64? = nil,
        tracksLog: Bool = true,
        tracksEvents: Bool = true,
        dealOpeningHand: Bool = true,
        appliesFightPacing: Bool = true
    ) {
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        let seed = rngSeed ?? Self.defaultRNGSeed
        let maxExistingEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activeCompanionEffects.map(\.id).max() ?? 0
        )
        self.init(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialHealth: heroStartingHealth,
                    initialActiveEffects: activeHeroEffects,
                    maximumHealthBonus: heroModifiers.maximumHealthBonus,
                    maximumManaBonus: heroModifiers.maximumManaBonus
                ),
                companion: CombatantRuntime(
                    combatant: companion,
                    initialHealth: companionStartingHealth,
                    initialActiveEffects: activeCompanionEffects,
                    maximumHealthBonus: companionModifiers.maximumHealthBonus,
                    maximumManaBonus: companionModifiers.maximumManaBonus
                ),
                enemy: CombatantRuntime(combatant: resolvedEnemy, initialActiveEffects: activeEnemyEffects)
            ),
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: maxExistingEffectID + 1,
            nextEventID: 0,
            events: [],
            gold: initialGold,
            initialGold: initialGold,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: enemyModifiers,
            enemyFaction: enemyFaction,
            tracksLog: tracksLog,
            tracksEvents: tracksEvents,
            appliesFightPacing: appliesFightPacing
        )

        _ = appendMilestone(.battleStarted(heroName: hero.name, companionName: companion.name))

        if dealOpeningHand {
            BattleCardCombatEngine.bootstrapDecksAndOpeningHand(context: &self)
        } else {
            BattleCardCombatEngine.bootstrapDecks(context: &self)
        }

        if tracksLog {
            var projection = BattleLogProjection()
            projection.sync(events: events)
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
    package mutating func withEngineContext<R>(_ body: (inout Self) throws -> R) rethrows -> R {
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
            context: &self
        )
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func endTurn(rebuildLog: Bool = true) -> [ActionEvent] {
        guard !isBattleOver else { return [] }
        let events = BattleCardCombatEngine.endTurn(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    /// Fills the opening hand in one step (tests / headless). Prefer paced
    /// `drawNextOpeningHandCard` when the UI should animate each draw.
    @discardableResult
    public mutating func drawOpeningHand(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.drawOpeningHand(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
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
    @discardableResult
    public mutating func finalizeOpeningHand(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.finalizeOpeningHand(context: &self)
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
            projection.rebuildFromScratch(events: events)
            logProjection = projection
        } else {
            logProjection?.sync(events: events)
        }
    }

    /// Drops the cached combat-log projection to reclaim memory. Call `syncLog()` to rebuild.
    public mutating func releaseLogProjection() {
        logProjection = nil
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events)
    }
}
