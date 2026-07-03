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
/// - Per-combatant state: `health(of:)`, `activeEffects(of:)`,
///   `effectSummaries(of:)`
/// - Global state: `tickCount`, `actionCount`, `events`, `gold`, `earnedGold`
/// - Derived: `log`
/// - Booleans: `isHeroAlive`, `isPetAlive`, `isEnemyDefeated`,
///   `isPartyDefeated`, `isBattleOver`
/// - AI helper: `enemyAttackTarget`
///
/// **Public surface (mutations):**
/// - `init(...)` — construct a battle
/// - `advanceOneStep() -> BattleStep` — drive the simulation by one tick
///
/// **Internal:**
/// - Per-combatant mutable state lives on `BattleRoster` (via three
///   `CombatantRuntime`s)
/// - Effect application rules live on the `BattleEffectHandler` structs in
///   `EffectHandlers.swift`; this type only orchestrates dispatch
/// - Combat log lines are derived from the event stream by `BattleLogReducer`
/// - Effect summaries are built by `EffectSummaryBuilder`
/// - Floating-text chrome is formatted by `ActionEventFormatter`
public struct BattleState {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant

    // MARK: - Global mutable state (lives on BattleState itself)

    public private(set) var tickCount: Int
    public var actionCount: Int
    public var events: [ActionEvent]
    public private(set) var gold: Int

    public var roster: BattleRoster
    public var nextEventID: Int
    public var nextEffectID: Int
    public var rng: SeededRandomNumberGenerator
    private var hasLoggedDefeat: Bool
    private var hasLoggedPartyDefeat: Bool
    public let combatBuild: BattleCombatBuild
    private let initialGold: Int

    /// Cached combat log. Rebuilt automatically after every event mutation.
    public private(set) var log: [LogEntry] = []

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
        _ = appendMilestone(.battleStarted)
        rebuildLog()
    }

    // MARK: - Per-combatant state accessors (delegate to roster)

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

    public func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    public func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    public func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    public func health(for role: Combatant.Role) -> Int {
        switch role {
        case .hero: roster.hero.currentHealth
        case .pet: roster.pet.currentHealth
        case .enemy: roster.enemy.currentHealth
        }
    }

    public func activeEffects(for role: Combatant.Role) -> [ActiveEffect] {
        switch role {
        case .hero: roster.hero.activeEffects
        case .pet: roster.pet.activeEffects
        case .enemy: roster.enemy.activeEffects
        }
    }

    public func effectSummaries(for role: Combatant.Role) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(for: role))
    }

    // MARK: - Roster helpers (replace the 6 deleted dispatch methods)

    public func runtime(for combatant: Combatant) -> CombatantRuntime {
        guard let runtime = roster.runtime(for: combatant) else {
            preconditionFailure("Unknown combatant id \(combatant.id)")
        }
        return runtime
    }

    public mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    // MARK: - Modifier profile

    public func modifiers(for combatantID: String) -> CombatModifierProfile {
        combatBuild.modifiers(for: combatantID)
    }

    // MARK: - Engine context

    /// Copies the relevant mutable fields into a `BattleEngineContext`, runs
    /// `body`, then copies the mutated context back into `self`.
    public mutating func withEngineContext<R>(_ body: (inout BattleEngineContext) throws -> R) rethrows -> R {
        var context = BattleEngineContext(
            roster: roster,
            rng: rng,
            nextEffectID: nextEffectID,
            nextEventID: nextEventID,
            events: events,
            gold: gold,
            build: combatBuild
        )
        let result = try body(&context)
        roster = context.roster
        rng = context.rng
        nextEffectID = context.nextEffectID
        nextEventID = context.nextEventID
        events = context.events
        gold = context.gold
        rebuildLog()
        return result
    }

    // MARK: - Pipeline forwarding

    public mutating func applyDamage(
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

    public mutating func applyHeal(_ amount: Int, to combatant: Combatant, sourceActorID: String? = nil) {
        withEngineContext { context in
            CombatPipeline.applyHeal(amount, to: combatant, sourceActorID: sourceActorID, in: &context)
        }
    }

    public mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        withEngineContext { context in
            CombatPipeline.applyLeechFromDamage(damage, sourceActorID: sourceActorID, in: &context)
        }
    }

    // MARK: - Turn loop

    /// Advances the battle by one global tick.
    ///
    /// **Tick contract**
    /// 1. Increment `tickCount` and run effect ticks for all living combatants
    ///    in order: enemy, then hero, then pet.
    /// 2. If the battle ended during effect ticks, emit defeat milestones and
    ///    return `.ended`.
    /// 3. Otherwise pick the next ready actor (at most one acts per step) using
    ///    roster scheduling rules.
    /// 4. Execute that actor's turn (or consume prevention), append defeat
    ///    milestones if needed, and return `.acted`, `.effectsOnly`, or
    ///    `.ended`.
    @discardableResult
    public mutating func advanceOneStep() -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        tickCount += 1
        var events = EffectTickEngine.tickAll(state: &self)

        if isBattleOver {
            events.append(contentsOf: appendDefeatMilestonesIfNeeded())
            return .ended(events: events)
        }

        guard let actor = BattleTurnEngine.readyCombatants(in: self).first else {
            return .effectsOnly(events: events)
        }

        events.append(contentsOf: BattleTurnEngine.act(actor: actor, state: &self))
        events.append(contentsOf: appendDefeatMilestonesIfNeeded())

        if isBattleOver {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }

    // MARK: - Combat pipeline (see CombatPipeline.swift)

    public mutating func nextEvent(
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
        rebuildLog()
        return event
    }

    private mutating func rebuildLog() {
        log = BattleLogReducer.entries(
            from: events,
            matchup: BattleMatchup(hero: hero, pet: pet, enemy: enemy)
        )
    }

    @discardableResult
    private mutating func appendMilestone(_ milestone: ActionEvent.Milestone) -> ActionEvent {
        nextEvent(
            kind: .milestone,
            actorName: "",
            abilityName: "",
            target: enemy,
            amount: 0,
            keyword: .physical,
            milestone: milestone
        )
    }

    private mutating func appendDefeatMilestonesIfNeeded() -> [ActionEvent] {
        var milestones: [ActionEvent] = []
        if isEnemyDefeated, !hasLoggedDefeat {
            hasLoggedDefeat = true
            milestones.append(appendMilestone(.enemyDefeated))
        }
        if isPartyDefeated, !hasLoggedPartyDefeat {
            hasLoggedPartyDefeat = true
            milestones.append(appendMilestone(.partyDefeated))
        }
        return milestones
    }
}
