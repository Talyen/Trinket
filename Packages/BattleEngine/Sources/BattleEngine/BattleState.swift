import Foundation
import TrinketContent
import TrinketCore

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
        case criticalActionGold
        case poisonStun
    }

    public var kind: Kind
    public var actorID: String

    public init(kind: Kind, actorID: String) {
        self.kind = kind
        self.actorID = actorID
    }
}

public struct BattleState {
    public let rngSeed: UInt64

    public let tracksLog: Bool

    public let tracksEvents: Bool

    public enum BattleObservationMode: Sendable {
        case none, eventsOnly, fullLog
        var tracksLog: Bool {
            self == .fullLog
        }

        var tracksEvents: Bool {
            self != .none
        }
    }

    public var observationMode: BattleObservationMode {
        switch (tracksLog, tracksEvents) {
        case (true, true): .fullLog
        case (false, true): .eventsOnly
        case (false, false): .none
        case (true, false): .none
        }
    }

    public var appliesFightPacing: Bool

    public var roster: BattleRoster
    public var rng: SeededRandomNumberGenerator
    public var boonRNG: SeededRandomNumberGenerator
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
    public var lastEnemyDefeatWasCritical: Bool

    public var phase: BattlePhase
    public var hand: BattleHand
    public var heroDeck: CombatDeck
    public var companionDeck: CombatDeck
    public var openingHandDealPlan: [OpeningHandDraw]
    public var nextCardID: Int
    public var ownersSkippingThisPlayerTurn: Set<BattleParticipant>
    public var turnCadence: BattleTurnCadence

    public var additionalControlSkipsByCombatantID: [String: Int]
    public var isResolvingTalentReaction: Bool
    public var isResolvingDoTDetonation: Bool
    public var talentActionGuardByActorID: [TalentActionGuardKey: Int]
    public var talentTurnGuardByActorID: [TalentActionGuardKey: Int]
    public var skillEchoOwnersThisBattle: Set<String>
    public var talentReactionDepth: Int
    public var dotRecursionDepth: Int
    public var isResolvingAutoPlayCard: Bool
    public var drawAndPlayDepth: Int = 0
    public var activeBoons: [ActiveBoon]
    public var pendingBoonOffer: BoonOffer?
    public var hasOfferedStartBoon: Bool
    public var usedBoonArtworkNames: Set<String>
    public var boonRuntime: BoonRuntime
    public static let maxDrawAndPlayDepth = ReactionScope.maxDrawAndPlayDepth
    public let enemyFaction: EnemyFaction

    public var partyTriggers: CombatTraitTriggers {
        CombatTriggerEngine.livingPartyTriggers(in: self)
    }

    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

    package init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        boonRNG: SeededRandomNumberGenerator? = nil,
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
        heroDeck: CombatDeck = CombatDeck(),
        companionDeck: CombatDeck = CombatDeck(),
        openingHandDealPlan: [OpeningHandDraw] = [],
        nextCardID: Int = 0,
        ownersSkippingThisPlayerTurn: Set<BattleParticipant> = [],
        turnCadence: BattleTurnCadence = BattleTurnCadence(),
        additionalControlSkipsByCombatantID: [String: Int] = [:],
        isResolvingTalentReaction: Bool = false,
        isResolvingDoTDetonation: Bool = false,
        talentActionGuardByActorID: [TalentActionGuardKey: Int] = [:],
        talentTurnGuardByActorID: [TalentActionGuardKey: Int] = [:],
        skillEchoOwnersThisBattle: Set<String> = [],
        talentReactionDepth: Int = 0,
        dotRecursionDepth: Int = 0,
        isResolvingAutoPlayCard: Bool = false,
        drawAndPlayDepth: Int = 0,
        activeBoons: [ActiveBoon] = [],
        pendingBoonOffer: BoonOffer? = nil,
        hasOfferedStartBoon: Bool = false,
        usedBoonArtworkNames: Set<String> = [],
        boonRuntime: BoonRuntime = BoonRuntime(),
        enemyFaction: EnemyFaction = .mortal,
        tracksLog: Bool = false,
        tracksEvents: Bool = true,
        appliesFightPacing: Bool = true,
    ) {
        precondition(!(tracksLog && !tracksEvents), "tracksLog requires tracksEvents")
        rngSeed = rng.seed
        self.tracksLog = tracksLog
        self.tracksEvents = tracksEvents
        self.appliesFightPacing = appliesFightPacing
        self.roster = roster
        self.rng = rng
        self.boonRNG = boonRNG ?? BoonEngine.makeRNG(forking: rng)
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
        self.heroDeck = heroDeck
        self.companionDeck = companionDeck
        self.openingHandDealPlan = openingHandDealPlan
        self.nextCardID = nextCardID
        self.ownersSkippingThisPlayerTurn = ownersSkippingThisPlayerTurn
        self.turnCadence = turnCadence
        self.additionalControlSkipsByCombatantID = additionalControlSkipsByCombatantID
        self.isResolvingTalentReaction = isResolvingTalentReaction
        self.isResolvingDoTDetonation = isResolvingDoTDetonation
        self.talentActionGuardByActorID = talentActionGuardByActorID
        self.talentTurnGuardByActorID = talentTurnGuardByActorID
        self.skillEchoOwnersThisBattle = skillEchoOwnersThisBattle
        self.talentReactionDepth = talentReactionDepth
        self.dotRecursionDepth = dotRecursionDepth
        self.isResolvingAutoPlayCard = isResolvingAutoPlayCard
        self.drawAndPlayDepth = drawAndPlayDepth
        self.activeBoons = activeBoons
        self.pendingBoonOffer = pendingBoonOffer
        self.hasOfferedStartBoon = hasOfferedStartBoon
        self.usedBoonArtworkNames = usedBoonArtworkNames
        self.boonRuntime = boonRuntime

        self.enemyFaction = enemyFaction
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
        heroStartingHealth: Int? = nil,
        companionStartingHealth: Int? = nil,
        enemyFaction: EnemyFaction = .mortal,
        rngSeed: UInt64? = nil,
        tracksLog: Bool = true,
        tracksEvents: Bool = true,
        dealOpeningHand: Bool = true,
        appliesFightPacing: Bool = true,
    ) {
        let resolvedEnemy = enemy ?? Enemy.fallbackCombatant
        let seed = rngSeed ?? Self.defaultRNGSeed
        let maxExistingEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activeCompanionEffects.map(\.id).max() ?? 0,
        )
        self.init(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialHealth: heroStartingHealth,
                    initialActiveEffects: activeHeroEffects,
                    maximumHealthBonus: heroModifiers.maximumHealthBonus,
                    maximumManaBonus: heroModifiers.maximumManaBonus,
                ),
                companion: CombatantRuntime(
                    combatant: companion,
                    initialHealth: companionStartingHealth,
                    initialActiveEffects: activeCompanionEffects,
                    maximumHealthBonus: companionModifiers.maximumHealthBonus,
                    maximumManaBonus: companionModifiers.maximumManaBonus,
                ),
                enemy: CombatantRuntime(combatant: resolvedEnemy, initialActiveEffects: activeEnemyEffects),
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
            appliesFightPacing: appliesFightPacing,
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

    public var log: [LogEntry] {
        logProjection?.entries ?? []
    }

    package mutating func withEngineContext<R>(_ body: (inout Self) throws -> R) rethrows -> R {
        let result = try body(&self)
        finishMutation(rebuildLog: true)
        return result
    }

    package mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    @discardableResult
    public mutating func playCard(
        cardID: Int,
        rebuildLog: Bool = true,
    ) throws -> [ActionEvent] {
        guard !isBattleOver else { throw BattlePlayError.battleOver }
        guard !hasPendingBoonOffer else { throw BattlePlayError.boonChoicePending }
        let events = try BattleCardCombatEngine.playCard(
            cardID: cardID,
            context: &self,
        )
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func endTurn(rebuildLog: Bool = true) -> [ActionEvent] {
        guard !isBattleOver else { return [] }
        guard !hasPendingBoonOffer else { return [] }
        let events = BattleCardCombatEngine.endTurn(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func drawOpeningHand(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.drawOpeningHand(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func drawNextOpeningHandCard(rebuildLog: Bool = true) -> Bool {
        let drew = BattleCardCombatEngine.drawNextOpeningHandCard(context: &self)
        if drew {
            finishMutation(rebuildLog: rebuildLog)
        }
        return drew
    }

    @discardableResult
    public mutating func finalizeOpeningHand(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.finalizeOpeningHand(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    public func isCardPlayable(_ card: BattleCard) -> Bool {
        !hasPendingBoonOffer && BattleCardCombatEngine.isCardPlayable(card, in: self)
    }

    public mutating func syncLog() {
        if logProjection == nil {
            var projection = BattleLogProjection()
            projection.rebuildFromScratch(events: events)
            logProjection = projection
        } else {
            logProjection?.sync(events: events)
        }
    }

    public mutating func releaseLogProjection() {
        logProjection = nil
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events)
    }
}
