import Foundation
import TrinketContent
import TrinketCore

package enum TalentClaim: Hashable, Sendable {
    case spendOvercharge
    case darkRecovery
    case surpriseStrike
    case seismicRoar
    case endlessLegion
    case criticalActionGold
    case poisonStun
    case cleanSlate
    case stolenThunder
    case pulverize
    case overhealFirstBlock
}

public struct TurnDrawState: Hashable, Sendable {
    var remaining: [BattleParticipant: Int]
    var tieWinner: BattleParticipant
    var heroHandCount: Int
    var companionHandCount: Int
}

// swiftlint:disable:next type_body_length - BattleState is intentional battle facade
public struct BattleState {
    var cardPlayRecording: BattleCardPlayRecording?

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

    public package(set) var appliesFightPacing: Bool

    public package(set) var roster: BattleRoster
    public package(set) var rng: SeededRandomNumberGenerator
    public package(set) var turnCount: Int
    public package(set) var nextEffectID: Int
    public package(set) var nextEventID: Int
    public package(set) var events: [ActionEvent]
    public package(set) var gold: Int {
        get { initialGold + goldFlow.net }
        set { goldFlow.record(delta: newValue - gold) }
    }

    public private(set) var goldFlow: BattleGoldFlow
    public let initialGold: Int
    private final class ModifierProfiles: Sendable {
        let hero: CombatModifierProfile
        let companion: CombatModifierProfile
        let enemy: CombatModifierProfile

        init(hero: CombatModifierProfile, companion: CombatModifierProfile, enemy: CombatModifierProfile) {
            self.hero = hero
            self.companion = companion
            self.enemy = enemy
        }
    }

    private let modifierProfiles: ModifierProfiles

    public var heroModifiers: CombatModifierProfile {
        modifierProfiles.hero
    }

    public var companionModifiers: CombatModifierProfile {
        modifierProfiles.companion
    }

    public var enemyModifiers: CombatModifierProfile {
        modifierProfiles.enemy
    }

    public package(set) var actionCount: Int
    public package(set) var hasLoggedDefeat: Bool
    public package(set) var hasLoggedPartyDefeat: Bool
    public package(set) var lastEnemyDefeatWasCritical: Bool

    public package(set) var phase: BattlePhase
    public package(set) var hand: BattleHand
    public package(set) var heroDeck: CombatDeck
    public package(set) var companionDeck: CombatDeck
    public package(set) var openingHandDealPlan: [OpeningHandDraw]
    public package(set) var nextCardID: Int
    public package(set) var ownersSkippingThisPlayerTurn: Set<BattleParticipant>
    public package(set) var turnCadence: BattleTurnCadence

    public package(set) var additionalControlSkipsByCombatantID: [String: Int]
    public package(set) var isEchoingSkill: Bool
    public static let maxDrawAndPlayDepth = ReactionScope.maxDrawAndPlayDepth
    public let enemyFaction: EnemyFaction
    public package(set) var storedBlockedDamageByActorID: [String: Int] = [:]
    public package(set) var primedRepeatKeywords: Set<Keyword> = []
    var resolution = CombatResolution()
    var heroTalents = HeroTalentState()
    var uniques = UniqueBattleState()
    var pendingTurnDrawState: TurnDrawState?

    public var partyTriggers: CombatTraitTriggers {
        CombatTriggerEngine.livingPartyTriggers(in: self)
    }

    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

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
        heroDeck: CombatDeck = CombatDeck(),
        companionDeck: CombatDeck = CombatDeck(),
        openingHandDealPlan: [OpeningHandDraw] = [],
        nextCardID: Int = 0,
        ownersSkippingThisPlayerTurn: Set<BattleParticipant> = [],
        turnCadence: BattleTurnCadence = BattleTurnCadence(),
        additionalControlSkipsByCombatantID: [String: Int] = [:],
        isEchoingSkill: Bool = false,
        enemyFaction: EnemyFaction = .mortal,
        tracksLog: Bool = false,
        tracksEvents: Bool = true,
        appliesFightPacing: Bool = true,
        pendingTurnDrawState: TurnDrawState? = nil,
    ) {
        precondition(!(tracksLog && !tracksEvents), "tracksLog requires tracksEvents")
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
        goldFlow = BattleGoldFlow(gained: max(0, gold - initialGold), spent: max(0, initialGold - gold))
        self.initialGold = initialGold
        modifierProfiles = ModifierProfiles(hero: heroModifiers, companion: companionModifiers, enemy: enemyModifiers)
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
        self.isEchoingSkill = isEchoingSkill
        self.pendingTurnDrawState = pendingTurnDrawState

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
        recording: ((BattleTransitionCheckpoint, Self, [ActionEvent]) -> Void)? = nil,
    ) throws -> [ActionEvent] {
        guard !isBattleOver else { throw BattlePlayError.battleOver }
        cardPlayRecording = recording.map(BattleCardPlayRecording.init)
        defer { cardPlayRecording = nil }
        let events = try BattleCardCombatEngine.playCard(
            cardID: cardID,
            context: &self,
        )
        finishMutation(rebuildLog: rebuildLog)
        recordCardPlay(.ready)
        return events
    }

    @discardableResult
    public mutating func endTurn(
        rebuildLog: Bool = true,
        recording: ((BattleTransitionCheckpoint, Self, [ActionEvent]) -> Void)? = nil,
    ) -> [ActionEvent] {
        guard !isBattleOver else { return [] }
        let events = BattleCardCombatEngine.endTurn(context: &self, recording: recording)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    public mutating func drawOpeningHand(
        rebuildLog: Bool = true,
        recording: ((BattleTransitionCheckpoint, Self, [ActionEvent]) -> Void)? = nil,
    ) -> [ActionEvent] {
        let events = BattleCardCombatEngine.drawOpeningHand(context: &self, recording: recording)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    package mutating func drawNextOpeningHandCard(rebuildLog: Bool = true) -> Bool {
        let drew = BattleCardCombatEngine.drawNextOpeningHandCard(context: &self)
        if drew {
            finishMutation(rebuildLog: rebuildLog)
        }
        return drew
    }

    @discardableResult
    package mutating func finalizeOpeningHand(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.finalizeOpeningHand(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    package mutating func endTurnWithoutDraw(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.endTurnWithoutDraw(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    package mutating func drawNextTurnStartCard(rebuildLog: Bool = true) -> Bool {
        let drew = BattleCardCombatEngine.drawNextTurnStartCard(context: &self)
        if drew {
            finishMutation(rebuildLog: rebuildLog)
        }
        return drew
    }

    @discardableResult
    package mutating func finalizeTurnStart(rebuildLog: Bool = true) -> [ActionEvent] {
        let events = BattleCardCombatEngine.finalizeTurnStart(context: &self)
        finishMutation(rebuildLog: rebuildLog)
        return events
    }

    @discardableResult
    package mutating func promoteNextTurnBufferCard(rebuildLog: Bool = true) -> BattleCard? {
        let card = BattleCardCombatEngine.promoteNextFromBuffer(context: &self)
        if card != nil {
            finishMutation(rebuildLog: rebuildLog)
        }
        return card
    }

    public func isCardPlayable(_ card: BattleCard) -> Bool {
        BattleCardCombatEngine.isCardPlayable(card, in: self)
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

    package mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        CombatResolver.damage(request, in: &self)
    }

    package mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &self)
    }

    package mutating func applyControlMeter(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
    ) -> [ActionEvent] {
        ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            in: &self,
        )
    }

    package mutating func resolveDoTTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
    ) -> CombatOutcome {
        DoTDamage.resolveTurnDamage(
            basePotency: basePotency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            in: &self,
        )
    }

    package mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
    ) -> [ActionEvent] {
        DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            application: application,
            in: &self,
        )
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events)
    }
}
