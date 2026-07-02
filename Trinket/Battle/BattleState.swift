import Foundation

/// The state of a single battle. `BattleState` is the top-level facade
/// drivers (UI, simulation) interact with: it exposes the per-combatant
/// read-only views (`heroHealth`, `activeHeroEffects`, `heroEffectSummaries`,
/// etc.) and the single mutable entry point `advanceOneStep()` that ticks
/// the simulation forward by one step.
///
/// **Public surface (read-only views):**
/// - Combatant definitions: `hero`, `pet`, `enemy`
/// - Per-combatant state: `heroHealth`/`petHealth`/`enemyHealth`,
///   `activeHeroEffects`/`activePetEffects`/`activeEnemyEffects`,
///   `heroActionCount`/`petActionCount`/`enemyActionCount`,
///   `heroEffectSummaries`/`petEffectSummaries`/`enemyEffectSummaries`
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
struct BattleState {
    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    // MARK: - Global mutable state (lives on BattleState itself)

    private(set) var tickCount: Int
    var actionCount: Int
    var events: [ActionEvent]
    private(set) var gold: Int

    var roster: BattleRoster
    var nextEventID: Int
    var nextEffectID: Int
    var rng: SeededRandomNumberGenerator
    private var hasLoggedDefeat: Bool
    private var hasLoggedPartyDefeat: Bool
    let combatBuild: BattleCombatBuild
    private let initialGold: Int

    var log: [LogEntry] {
        BattleLogReducer.entries(
            from: events,
            matchup: BattleMatchup(hero: hero, pet: pet, enemy: enemy)
        )
    }

    static let defaultRNGSeed: UInt64 = 0

    init(
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
        let resolvedEnemy = enemy ?? Enemy.randomNormalCombatant
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
                maximumHealthBonus: heroModifiers.maximumHealthBonus
            ),
            pet: CombatantRuntime(
                combatant: pet,
                initialActiveEffects: activePetEffects,
                maximumHealthBonus: petModifiers.maximumHealthBonus
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
    }

    // MARK: - Per-combatant state accessors (delegate to roster)

    var heroHealth: Int {
        roster.hero.currentHealth
    }

    var petHealth: Int {
        roster.pet.currentHealth
    }

    var enemyHealth: Int {
        roster.enemy.currentHealth
    }

    var activeEnemyEffects: [ActiveEffect] {
        roster.enemy.activeEffects
    }

    var activeHeroEffects: [ActiveEffect] {
        roster.hero.activeEffects
    }

    var activePetEffects: [ActiveEffect] {
        roster.pet.activeEffects
    }

    var heroActionCount: Int {
        roster.hero.actionCount
    }

    var petActionCount: Int {
        roster.pet.actionCount
    }

    var enemyActionCount: Int {
        roster.enemy.actionCount
    }

    var earnedGold: Int {
        gold - initialGold
    }

    var isEnemyDefeated: Bool {
        roster.isEnemyDefeated
    }

    var isHeroAlive: Bool {
        roster.hero.isAlive
    }

    var isPetAlive: Bool {
        roster.pet.isAlive
    }

    var isPartyDefeated: Bool {
        roster.isPartyDefeated
    }

    var isBattleOver: Bool {
        isEnemyDefeated || isPartyDefeated
    }

    var enemyAttackTarget: Combatant {
        roster.enemyAttackTarget
    }

    func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    func activeEffects(of combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    func effectSummaries(of combatant: Combatant) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(of: combatant))
    }

    func health(for role: Combatant.Role) -> Int {
        switch role {
        case .hero: roster.hero.currentHealth
        case .pet: roster.pet.currentHealth
        case .enemy: roster.enemy.currentHealth
        }
    }

    func activeEffects(for role: Combatant.Role) -> [ActiveEffect] {
        switch role {
        case .hero: roster.hero.activeEffects
        case .pet: roster.pet.activeEffects
        case .enemy: roster.enemy.activeEffects
        }
    }

    func effectSummaries(for role: Combatant.Role) -> [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEffects(for: role))
    }

    var enemyEffectSummaries: [EffectSummary] {
        EffectSummaryBuilder.build(for: activeEnemyEffects)
    }

    var heroEffectSummaries: [EffectSummary] {
        EffectSummaryBuilder.build(for: activeHeroEffects)
    }

    var petEffectSummaries: [EffectSummary] {
        EffectSummaryBuilder.build(for: activePetEffects)
    }

    // MARK: - Roster helpers (replace the 6 deleted dispatch methods)

    func runtime(for combatant: Combatant) -> CombatantRuntime {
        guard let runtime = roster.runtime(for: combatant) else {
            preconditionFailure("Unknown combatant id \(combatant.id)")
        }
        return runtime
    }

    mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    // MARK: - Mutation context

    func makeMutationContext() -> BattleMutationContext {
        BattleMutationContext(
            roster: roster,
            rng: rng,
            nextEffectID: nextEffectID,
            nextEventID: nextEventID,
            events: events,
            gold: gold,
            build: combatBuild
        )
    }

    mutating func applyMutationContext(_ context: BattleMutationContext) {
        roster = context.roster
        rng = context.rng
        nextEffectID = context.nextEffectID
        nextEventID = context.nextEventID
        events = context.events
        gold = context.gold
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
    mutating func advanceOneStep() -> BattleStep {
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

        if actor.role == .enemy, isEnemyDefeated {
            return .effectsOnly(events: events)
        }

        let abilityTarget = actor.role == .enemy ? enemyAttackTarget : enemy
        if hasActivePrevention(actor: actor) {
            events.append(contentsOf: BattleTurnEngine.consumePrevention(for: actor, state: &self))
        } else {
            events.append(contentsOf: BattleTurnEngine.performAction(actor: actor, abilityTarget: abilityTarget, state: &self))
        }

        events.append(contentsOf: appendDefeatMilestonesIfNeeded())

        if isBattleOver {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }

    func hasActivePrevention(actor: Combatant) -> Bool {
        roster.activeEffects(for: actor).contains(where: {
            if case .prevention = $0.effect, $0.remainingTicks > 0 { return true }
            return false
        })
    }

    // MARK: - Combat pipeline (see CombatPipeline.swift)

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
