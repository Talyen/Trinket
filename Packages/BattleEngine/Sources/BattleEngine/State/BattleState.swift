import Foundation
import TrinketContent
import TrinketCore

public struct BattleState {
    public var defeatProgress: BattleDefeatProgress {
        roster.enemy.defeatProgress
    }

    var commandOutput: BattleCommandOutput?

    public let rngSeed: UInt64

    public let tracksLog: Bool

    public let tracksEvents: Bool

    public package(set) var appliesFightPacing: Bool

    public package(set) var roster: BattleRoster
    public package(set) var rng: SeededRandomNumberGenerator
    public package(set) var turnCount: Int = 0
    public package(set) var nextEffectID: Int
    public package(set) var nextEventID: Int = 0
    public package(set) var events: [ActionEvent] = []
    public package(set) var gold: Int {
        get { SaturatedArithmetic.saturatingAdd(initialGold, goldFlow.net) }
        set { goldFlow.record(delta: SaturatedArithmetic.saturatingSub(newValue, gold)) }
    }

    mutating func recordGoldGain(_ amount: Int) -> Int {
        let previous = goldFlow.gained
        goldFlow.record(delta: max(0, amount))
        return goldFlow.gained - previous
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

    public package(set) var actionCount: Int = 0
    public package(set) var hasLoggedDefeat: Bool = false
    public package(set) var hasLoggedPartyDefeat: Bool = false
    public package(set) var lastEnemyDefeatWasCritical: Bool = false
    package var lastEnemyDefeatSourceActorID: String?

    var turnState: BattleTurnState = .playerTurn

    public var phase: BattlePhase {
        turnState.phase
    }

    public package(set) var hand: BattleHand = .init()
    public package(set) var heroDeck: CombatDeck = .init()
    public package(set) var companionDeck: CombatDeck = .init()
    var nextScheduledDrawOwner: BattleParticipant = .hero
    public package(set) var nextCardID: Int = 0
    public package(set) var ownersSkippingThisPlayerTurn: Set<BattleParticipant> = []
    public package(set) var turnCadence: BattleTurnCadence = .init()

    var additionalControlSkipsByEffectID: [Int: Int] = [:]
    public package(set) var isEchoingSkill: Bool = false
    /// Retains the shipped automatic-chain limit. CombatExecutor suspends
    /// nested plays on the heap, independently of the caller's stack size.
    /// Played deck copies remain discarded until the next turn.
    public static let maxDrawAndPlayDepth = 4
    public let enemyFaction: EnemyFaction

    var resolution = CombatResolution()
    var uniques = UniqueBattleState()

    private var logProjection: BattleLogProjection?

    public static let defaultRNGSeed: UInt64 = 0

    package init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        initialGold: Int,
        heroModifiers: CombatModifierProfile,
        companionModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile,
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
        nextEffectID = max(
            roster.hero.activeEffects.lazy.map(\.id).max() ?? 0,
            roster.companion.activeEffects.lazy.map(\.id).max() ?? 0,
            roster.enemy.activeEffects.lazy.map(\.id).max() ?? 0,
        ) + 1
        goldFlow = BattleGoldFlow()
        self.initialGold = initialGold
        modifierProfiles = ModifierProfiles(hero: heroModifiers, companion: companionModifiers, enemy: enemyModifiers)

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
        self.init(
            roster: BattleRoster(
                hero: Self.startingRuntime(
                    for: hero, modifiers: heroModifiers, health: heroStartingHealth, effects: activeHeroEffects,
                ),
                companion: Self.startingRuntime(
                    for: companion, modifiers: companionModifiers, health: companionStartingHealth, effects: activeCompanionEffects,
                ),
                enemy: Self.startingRuntime(for: resolvedEnemy, modifiers: enemyModifiers, effects: activeEnemyEffects),
            ),
            rng: SeededRandomNumberGenerator(seed: rngSeed ?? Self.defaultRNGSeed),
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

        if enemyModifiers.triggers.startBattleBlock > 0 {
            applyBlockGain(
                enemyModifiers.triggers.startBattleBlock,
                to: resolvedEnemy, source: resolvedEnemy,
                abilityName: "Shielded Arrival", amountBasis: .resolved,
            )
        }

        BattleCardCombatEngine.bootstrapDecks(context: &self)
        if dealOpeningHand {
            CombatExecutor.run { await BattleCardCombatEngine.drawOpeningHand(context: &self) }
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

    package mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    @discardableResult
    public mutating func playCard(
        cardID: Int,
        rebuildLog: Bool = true,
        recordActions: Bool = false,
    ) throws -> BattleCommandResult {
        guard !isBattleOver else { throw BattlePlayError.battleOver }
        return try CombatExecutor.run {
            try await performCommand(rebuildLog: rebuildLog, recordActions: recordActions) { context in
                try await BattleCardCombatEngine.playCard(cardID: cardID, context: &context)
            }
        }
    }

    @discardableResult
    public mutating func endTurn(
        rebuildLog: Bool = true,
        recordActions: Bool = false,
    ) -> BattleCommandResult {
        guard !isBattleOver else { return .empty }
        return CombatExecutor.run {
            await performCommand(rebuildLog: rebuildLog, recordActions: recordActions) { context in
                await BattleCardCombatEngine.endTurn(context: &context)
            }
        }
    }

    @discardableResult
    public mutating func drawOpeningHand(
        rebuildLog: Bool = true,
        recordActions: Bool = false,
    ) -> BattleCommandResult {
        CombatExecutor.run {
            await performCommand(rebuildLog: rebuildLog, recordActions: recordActions) { context in
                await BattleCardCombatEngine.drawOpeningHand(context: &context)
            }
        }
    }

    private mutating func performCommand(
        rebuildLog: Bool,
        recordActions: Bool = false,
        _ operation: (inout Self) async throws -> Void,
    ) async rethrows -> BattleCommandResult {
        precondition(commandOutput == nil, "Internal rules must use the active command's executor")
        let output = BattleCommandOutput(recordActions: recordActions)
        commandOutput = output
        defer { commandOutput = nil }
        try await operation(&self)
        finishMutation(rebuildLog: rebuildLog)
        return output.result
    }

    public func isCardPlayable(_ card: BattleCard) -> Bool {
        BattleCardCombatEngine.isCardPlayable(card, in: self)
    }

    package var playerTurnNumber: Int {
        turnCount + 1
    }

    package func isPlayerTurn(every interval: Int, startingAt first: Int? = nil) -> Bool {
        let first = first ?? interval
        return interval > 0 && playerTurnNumber >= first && (playerTurnNumber - first).isMultiple(of: interval)
    }

    package func paced(_ amount: Int, sourceActorID: String?) -> Int {
        guard appliesFightPacing,
              amount > 0,
              let sourceActorID,
              let side = FightPacing.side(for: sourceActorID, in: self)
        else { return amount }
        let metrics = FightPacing.poolMetrics(in: self)
        let multiplier = FightPacing.multiplier(
            side: side,
            isBoss: FightPacing.isBossEnemy(in: self),
            metrics: metrics,
            in: self,
        )
        guard multiplier != 1 else { return amount }
        return CombatRounding.scaled(amount, multiplier: multiplier)
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

    package mutating func resolveDamage(_ request: DamageRequest) async -> CombatOutcome {
        await CombatResolver.damage(request, in: &self)
    }

    package mutating func resolveHeal(_ request: HealRequest) async -> CombatOutcome {
        await HealingEngine.resolveHeal(request, in: &self)
    }

    package mutating func applyControlMeter(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
    ) async {
        await ControlMeterEngine.applyMeterCharge(amount, keyword: keyword, to: combatant, sourceActorID: sourceActorID, in: &self)
    }

    package mutating func resolveDoTTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
    ) async -> CombatOutcome {
        await DoTDamage.resolveDamage(
            basePotency: basePotency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            operation: keyword == .burn || keyword == .poison ? .resolvedPeriodic : .periodic,
            in: &self,
        )
    }

    package mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance? = nil,
    ) async {
        await DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            application: application,
            provenance: provenance,
            in: &self,
        )
    }

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events)
    }
}

extension BattleState {
    static func startingRuntime(
        for combatant: Combatant, modifiers: CombatModifierProfile, health: Int? = nil, mana: Int? = nil, effects: [ActiveEffect],
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: combatant, initialHealth: health, initialMana: mana, initialActiveEffects: effects,
            maximumHealthBonus: CombatantMaxValues.maxHealth(for: combatant, modifiers: modifiers) - combatant.maxHealth,
            maximumManaBonus: SaturatedArithmetic.saturatingSub(
                CombatantMaxValues.maxMana(for: combatant, modifiers: modifiers), combatant.maxMana,
            ),
        )
    }
}
