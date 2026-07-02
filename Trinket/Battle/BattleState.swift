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
    static let defaultHeroActionIntervalTicks: Int = 2
    static let defaultPetActionIntervalTicks: Int = 2
    static let defaultEnemyActionIntervalTicks: Int = 6

    let hero: Combatant
    let pet: Combatant
    let enemy: Combatant

    // MARK: - Global mutable state (lives on BattleState itself)

    private(set) var tickCount: Int
    private(set) var actionCount: Int
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
        self.combatBuild = BattleCombatBuild(
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

    // MARK: - Effect-handler accessors (legacy; prefer BattleMutationContext)

    /// Returns the current health of `combatant` from the roster.
    func rosterHealth(for combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    /// Returns the active effects of `combatant` from the roster.
    func rosterActiveEffects(for combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    /// Replaces the active effects of `combatant` in the roster.
    mutating func rosterSetActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    /// Returns the next free effect ID and increments the counter.
    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + combatBuild.modifiers(for: sourceActorID).goldGainedBonus
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        combatBuild.adjustedOutgoingEffect(effect, sourceID: sourceID)
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
        var events = applyAllEffectTicks()

        if isBattleOver {
            events.append(contentsOf: appendDefeatMilestonesIfNeeded())
            return .ended(events: events)
        }

        guard let actor = readyCombatants().first else {
            return .effectsOnly(events: events)
        }

        if actor.role == .enemy, isEnemyDefeated {
            return .effectsOnly(events: events)
        }

        let abilityTarget = actor.role == .enemy ? enemyAttackTarget : enemy
        if hasActivePrevention(actor: actor) {
            events.append(contentsOf: consumePrevention(for: actor))
        } else {
            events.append(contentsOf: performAction(actor: actor, abilityTarget: abilityTarget))
        }

        events.append(contentsOf: appendDefeatMilestonesIfNeeded())

        if isBattleOver {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }

    private func readyCombatants() -> [Combatant] {
        roster.readyCombatants(atTick: tickCount).map(\.combatant)
    }

    func hasActivePrevention(actor: Combatant) -> Bool {
        roster.activeEffects(for: actor).contains(where: {
            if case .prevention = $0.effect, $0.remainingTicks > 0 { return true }
            return false
        })
    }

    private mutating func consumePrevention(for actor: Combatant) -> [ActionEvent] {
        var currentEffects = roster.activeEffects(for: actor)
        var events: [ActionEvent] = []

        if let index = currentEffects.firstIndex(where: {
            if case .prevention = $0.effect { return true }
            return false
        }) {
            let effect = currentEffects[index]
            let event = nextEvent(
                kind: .effect,
                effectKind: .preventionSkipped,
                actorName: effect.keyword.rawValue,
                abilityName: effect.keyword.rawValue,
                target: actor,
                amount: 0,
                keyword: effect.keyword
            )
            events.append(event)

            if effect.remainingTicks <= 1 {
                currentEffects.remove(at: index)
            } else {
                currentEffects[index].remainingTicks -= 1
            }
        }

        roster.setActiveEffects(currentEffects, for: actor)
        recordAction(for: actor)
        return events
    }

    private mutating func recordAction(for actor: Combatant) {
        actionCount += 1
        var runtime = runtime(for: actor)
        runtime.markActed(atTick: tickCount)
        updateRuntime(runtime)
    }

    private mutating func performAction(actor: Combatant, abilityTarget: Combatant) -> [ActionEvent] {
        let turnNumber = runtime(for: actor).actionCount + 1

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber) else {
            recordAction(for: actor)
            return []
        }

        var events: [ActionEvent] = []

        let (dealt, damageEvents) = applyDamage(
            ability.directDamage,
            to: abilityTarget,
            damageKeyword: ability.damageKeyword,
            sourceActorID: actor.id
        )
        events.append(contentsOf: damageEvents)
        if dealt > 0 {
            events.append(contentsOf: applyLeechFromDamage(dealt, sourceActorID: actor.id))
        }

        var appliedEffectLogs: [String] = []
        var pairedDamageHits: [(Keyword, Int)] = []
        if ability.directDamage > 0 {
            pairedDamageHits.append((ability.damageKeyword, ability.directDamage))
        }

        let effectsToApply: [TargetedEffect] = ability.targetedEffects.isEmpty
            ? (ability.statusApplication.map {
                [TargetedEffect(Effect.effect(from: $0), target: .abilityTarget)]
            } ?? [])
            : ability.targetedEffects

        var context = makeMutationContext()
        for targetedEffect in effectsToApply {
            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget
            )

            guard let handler = EffectHandlers.all[effect.kind] else { continue }
            let outcome = handler.apply(
                effect,
                ability: ability,
                source: actor,
                target: effectTarget,
                in: &context,
                pairedDamageHits: &pairedDamageHits
            )
            events.append(contentsOf: outcome.events)
            if outcome.didApply {
                appliedEffectLogs.append(effect.summary)
            }
        }
        applyMutationContext(context)

        events.append(
            nextEvent(
                kind: .ability,
                effectKind: nil,
                actorName: actor.name,
                abilityName: ability.name,
                target: abilityTarget,
                amount: dealt,
                keyword: ability.damageKeyword,
                appliedEffectSummaries: appliedEffectLogs
            )
        )

        recordAction(for: actor)
        return events
    }

    func shouldSkipImmediateDoT(
        potency: Int,
        keyword: Keyword,
        pairedDamageHits: [(Keyword, Int)]
    ) -> Bool {
        pairedDamageHits.contains(where: { $0 == (keyword, potency) })
    }

    private func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return enemy
        case .hero:
            return hero
        case .pet:
            return pet
        }
    }

    private func selectedAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    private func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) { return .ultimate }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) { return .skill }
        return .basic
    }

    private mutating func applyAllEffectTicks() -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickEffects(activeEnemyEffects, target: enemy)
        roster.setActiveEffects(enemyResult.updated, for: enemy)
        events.append(contentsOf: enemyResult.events)

        if isHeroAlive {
            let heroResult = tickEffects(activeHeroEffects, target: hero)
            roster.setActiveEffects(heroResult.updated, for: hero)
            events.append(contentsOf: heroResult.events)
        }

        if isPetAlive {
            let petResult = tickEffects(activePetEffects, target: pet)
            roster.setActiveEffects(petResult.updated, for: pet)
            events.append(contentsOf: petResult.events)
        }

        return events
    }

    private mutating func tickEffects(_ effects: [ActiveEffect], target: Combatant) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var remaining = effects

        guard roster.health(for: target) > 0 else {
            return (events, remaining)
        }

        // Phase 1: per-handler tick. `BleedHandler`, `BurnHandler`, and
        // `PoisonHandler` deal damage and update their own potency or
        // remaining ticks. Other kinds return a no-op outcome.
        var toRemove: [Int] = []
        var context = makeMutationContext()
        for index in remaining.indices {
            guard let handler = EffectHandlers.all[remaining[index].effect.kind] else { continue }
            let outcome = handler.tick(remaining[index], on: target, in: &context)
            events.append(contentsOf: outcome.events)
            if let updated = outcome.updatedStack {
                remaining[index] = updated
            }
            if outcome.removeAfter {
                toRemove.append(index)
            }
        }
        applyMutationContext(context)
        if !toRemove.isEmpty {
            let removeSet = Set(toRemove)
            remaining = remaining.enumerated().compactMap { index, ae in
                removeSet.contains(index) ? nil : ae
            }
        }

        // Phase 2: cleanse removal pass. Cleanses strip matching effects
        // and then re-add themselves so their own `remainingTicks` keeps
        // decrementing in the generic pass below.
        for ae in remaining {
            switch ae.effect {
            case let .cleanse(cleanseKeyword, _):
                if let removeKeyword = cleanseKeyword {
                    remaining.removeAll { $0.keyword == removeKeyword }
                } else {
                    remaining.removeAll { $0.effect.isTickable }
                }
                remaining.append(ae)

            default:
                break
            }
        }

        // Phase 3: generic duration decrement for effects not handled by
        // a per-handler `tick`. Bleed, burn, poison, prevention, and
        // preventionBuildup opt out (their lifecycle is managed by phase
        // 1 or by their own remainingTicks=0 self-removal).
        remaining = remaining.compactMap { ae in
            switch ae.effect {
            case .burn(0), .poison(0):
                return nil
            case .bleed:
                return ae.remainingTicks > 0 ? ae : nil
            case .burn, .poison:
                return ae
            case .prevention, .preventionBuildup:
                return ae
            default:
                var updated = ae
                updated.remainingTicks -= 1
                return updated.remainingTicks > 0 ? updated : nil
            }
        }

        return (events, remaining)
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
