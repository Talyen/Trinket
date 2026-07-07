import Foundation
import TrinketCore
import TrinketContent

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
/// - Rule engines mutate battle state in place during each step
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

    private let cachedMatchup: BattleMatchup
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
        cachedMatchup
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

    // MARK: - Engine context

    /// Runs `body` against the battle state in place, then refreshes the log
    /// when `tracksLog` is enabled.
    package mutating func withEngineContext<R>(_ body: (inout BattleEngineContext) throws -> R) rethrows -> R {
        let result = try body(&self)
        finishMutation(rebuildLog: true)
        return result
    }

    /// Test helper for seeding active effects without exposing `BattleRoster`.
    mutating func seedActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
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

    private mutating func finishMutation(rebuildLog: Bool) {
        guard rebuildLog, tracksLog else { return }
        logProjection?.sync(events: events, matchup: cachedMatchup)
    }
}

public extension BattleState {
    func modifiers(for combatantID: String) -> CombatModifierProfile {
        if combatantID == roster.hero.id { return heroModifiers }
        if combatantID == roster.pet.id { return petModifiers }
        if combatantID == roster.enemy.id { return enemyModifiers }
        return .zero
    }

    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer, durationTicks):
            return .shield(
                keyword,
                buffer + profile.blockGainedBonus,
                durationTicks + profile.blockDurationBonus
            )
        case let .mitigation(keyword, percent, durationTicks):
            return .mitigation(
                keyword,
                percent + profile.armorGainedBonus,
                durationTicks + profile.armorDurationBonus
            )
        case let .leech(keyword, percent, durationTicks):
            return .leech(
                keyword,
                percent + profile.leechGainedBonus,
                durationTicks + profile.leechDurationBonus
            )
        default:
            return effect
        }
    }

    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    mutating func restoreMana(_ amount: Int, to combatant: Combatant, sourceActorID _: String) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.restoreMana(amount)
        roster.update(runtime)
        return actual
    }

    @discardableResult
    mutating func spendMana(_ amount: Int, for combatant: Combatant) -> Int {
        guard var runtime = roster.runtime(for: combatant) else { return 0 }
        let actual = runtime.spendMana(amount)
        roster.update(runtime)
        return actual
    }

    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTicks: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.append(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTicks: remainingTicks,
                    sourceActorID: sourceID
                )
            )
        }
    }

    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTicks: Int
    ) {
        let effectID = consumeNextEffectID()
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.insert(
                ActiveEffect(
                    id: effectID,
                    effect: effect,
                    remainingTicks: remainingTicks,
                    sourceActorID: sourceID
                ),
                at: 0
            )
        }
    }

    mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }

        var state = DamageResolutionState(
            amount: request.amount,
            combatant: request.target,
            sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword,
            applyStatBonus: request.options.applyStatBonus,
            applyItemBonus: request.options.applyItemBonus,
            applyDodge: request.options.applyDodge,
            abilityCriticalChanceBonus: request.options.abilityCriticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: request.options.guaranteedCriticalIfEnemyBuffed,
            isRetaliation: request.options.isRetaliation,
            qualifiesForAmbush: request.options.qualifiesForAmbush
        )
        state.activeEffects = roster.activeEffects(for: request.target)

        DamagePipeline.run(state: &state, in: &self)

        return CombatOutcome.fromDamage(state: state)
    }

    mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &self)
    }

    mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        HealingEngine.leechFromDamage(damage, sourceActorID: sourceActorID, in: &self).events
    }

    mutating func applyControlMeter(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> [ActionEvent] {
        ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    mutating func resolveDoTTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?
    ) -> CombatOutcome {
        DoTDamage.resolveTick(
            basePotency: basePotency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            in: &self
        )
    }

    mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        DoTApplicator.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            dealImmediateDamage: dealImmediateDamage,
            in: &self
        )
    }

    mutating func nextEvent(
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        actorName: String,
        abilityName: String,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String] = [],
        milestone: ActionEvent.Milestone? = nil
    ) -> ActionEvent {
        nextEventID += 1
        let event = ActionEvent(
            id: nextEventID,
            kind: kind,
            effectKind: effectKind,
            actorName: actorName,
            abilityName: abilityName,
            targetID: target.id,
            targetName: target.name,
            amount: amount,
            keyword: keyword,
            appliedEffectSummaries: appliedEffectSummaries,
            milestone: milestone
        )
        events.append(event)
        return event
    }

    mutating func appendMilestone(_ milestone: ActionEvent.Milestone, matchup: BattleMatchup) -> ActionEvent {
        nextEvent(
            kind: .milestone,
            actorName: "",
            abilityName: "",
            target: matchup.enemy,
            amount: 0,
            keyword: .physical,
            milestone: milestone
        )
    }

    mutating func appendDefeatMilestonesIfNeeded(matchup: BattleMatchup) -> [ActionEvent] {
        var milestones: [ActionEvent] = []
        if roster.isEnemyDefeated, !hasLoggedDefeat {
            hasLoggedDefeat = true
            milestones.append(appendMilestone(.enemyDefeated, matchup: matchup))
        }
        if roster.isPartyDefeated, !hasLoggedPartyDefeat {
            hasLoggedPartyDefeat = true
            milestones.append(appendMilestone(.partyDefeated, matchup: matchup))
        }
        return milestones
    }
}
