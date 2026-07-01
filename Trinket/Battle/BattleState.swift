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
/// - Global state: `tickCount`, `actionCount`, `log`, `gold`, `earnedGold`
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
/// - Combat log lines are assembled by `BattleLogBuilder`
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
    private(set) var log: [LogEntry]
    private(set) var gold: Int

    private var roster: BattleRoster
    private var nextEventID: Int
    private var nextLogEntryID: Int
    private var nextEffectID: Int
    private var rng: SeededRandomNumberGenerator
    private var hasLoggedDefeat: Bool
    private var hasLoggedPartyDefeat: Bool
    private let initialGold: Int

    static let defaultRNGSeed: UInt64 = 0

    init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        rngSeed: UInt64? = nil
    ) {
        self.hero = hero
        self.pet = pet
        let resolvedEnemy = enemy ?? Enemy.randomNormalCombatant
        self.enemy = resolvedEnemy

        let seed = rngSeed ?? UInt64.random(in: UInt64.min ... UInt64.max)
        rng = SeededRandomNumberGenerator(seed: seed)

        tickCount = 0
        actionCount = 0

        roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialActiveEffects: activeHeroEffects),
            pet: CombatantRuntime(combatant: pet, initialActiveEffects: activePetEffects),
            enemy: CombatantRuntime(combatant: resolvedEnemy, initialActiveEffects: activeEnemyEffects)
        )

        nextEventID = 0
        nextLogEntryID = 1
        nextEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activePetEffects.map(\.id).max() ?? 0
        )
        hasLoggedDefeat = false
        hasLoggedPartyDefeat = false

        self.initialGold = initialGold
        gold = initialGold

        log = [
            LogEntry(id: 0, text: "\(hero.name) and \(pet.name) face \(resolvedEnemy.name).")
        ]
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

    // MARK: - Primary Stats Helpers

    private func maxHealth(for combatant: Combatant) -> Int {
        combatant.maxHealth + combatant.primaryStats.toughness
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

    private func runtime(for combatant: Combatant) -> CombatantRuntime {
        guard let runtime = roster.runtime(for: combatant) else {
            preconditionFailure("Unknown combatant id \(combatant.id)")
        }
        return runtime
    }

    private mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    // MARK: - Effect-handler accessors

    //
    // These are intentionally `internal` (not `private`) so the
    // `BattleEffectHandler` implementations in `EffectHandlers.swift` can
    // read and mutate battle state without going through `performAction`
    // itself.

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

    /// Returns the next free effect ID and increments the counter. Used by
    /// every handler that adds a new `ActiveEffect`.
    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    /// Adds `amount` to the battle's gold. Used by `ResourceGainHandler`.
    mutating func addGold(_ amount: Int) {
        gold += amount
    }

    // MARK: - Turn loop

    @discardableResult
    mutating func advanceOneStep() -> BattleStep {
        guard !isBattleOver else { return .ended(events: []) }

        tickCount += 1
        var events = applyAllEffectTicks()

        if isBattleOver {
            appendDefeatLogIfNeeded()
            appendPartyDefeatLogIfNeeded()
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

        appendDefeatLogIfNeeded()
        appendPartyDefeatLogIfNeeded()

        if isBattleOver {
            return .ended(events: events)
        }

        return .acted(actor, events: events)
    }

    private func readyCombatants() -> [Combatant] {
        roster.readyCombatants(atTick: tickCount).map(\.combatant)
    }

    private func hasActivePrevention(actor: Combatant) -> Bool {
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

        if ability.directDamage > 0 {
            let event = nextEvent(
                kind: .ability,
                effectKind: nil,
                actorName: actor.name,
                abilityName: ability.name,
                target: abilityTarget,
                amount: dealt,
                keyword: ability.damageKeyword
            )
            events.append(event)
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
                in: &self,
                pairedDamageHits: &pairedDamageHits
            )
            events.append(contentsOf: outcome.events)
            if outcome.didApply {
                appliedEffectLogs.append(effect.summary)
            }
        }

        let logLine = BattleLogBuilder.lineForAction(
            actorName: actor.name,
            abilityName: ability.name,
            dealt: dealt,
            damageKeyword: ability.damageKeyword,
            targetName: abilityTarget.name,
            appliedEffectSummaries: appliedEffectLogs
        )
        appendLog(logLine)

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

    mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        guard roster.health(for: effectTarget) > 0, potency > 0 else { return [] }
        let statBonus: Int
        if let actor = roster.combatant(for: sourceActorID) {
            statBonus = actor.primaryStats.statBonusForDamage(keyword: keyword)
        } else {
            statBonus = 0
        }
        let boostedPotency = potency + statBonus

        var events: [ActionEvent] = []
        if dealImmediateDamage {
            events.append(contentsOf: logDoTDamage(
                applyDoTDamage(boostedPotency, keyword: keyword, to: effectTarget, sourceActorID: sourceActorID),
                keyword: keyword,
                target: effectTarget
            ))
        }

        var currentEffects = roster.activeEffects(for: effectTarget)
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = effectCase(for: keyword, potency: existingPotency + boostedPotency)
            if currentEffects[index].sourceActorID == nil {
                currentEffects[index].sourceActorID = sourceActorID
            }
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: nextEffectID,
                    effect: effectCase(for: keyword, potency: boostedPotency),
                    remainingTicks: 0,
                    sourceActorID: sourceActorID
                )
            )
            nextEffectID += 1
        }
        roster.setActiveEffects(currentEffects, for: effectTarget)
        return events
    }

    mutating func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool
    ) -> [ActionEvent] {
        guard roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        let statBonus: Int
        if let actor = roster.combatant(for: sourceActorID) {
            statBonus = actor.primaryStats.statBonusForDamage(keyword: .bleed)
        } else {
            statBonus = 0
        }
        let boostedPotency = potency + statBonus

        var events: [ActionEvent] = []
        if dealImmediateDamage {
            events.append(contentsOf: logDoTDamage(
                applyDoTDamage(boostedPotency, keyword: .bleed, to: effectTarget, sourceActorID: sourceActorID),
                keyword: .bleed,
                target: effectTarget
            ))
        }

        var currentEffects = roster.activeEffects(for: effectTarget)
        currentEffects.append(
            ActiveEffect(
                id: nextEffectID,
                effect: .bleed(boostedPotency),
                remainingTicks: Effect.bleedDoTTickCount,
                sourceActorID: sourceActorID
            )
        )
        nextEffectID += 1
        roster.setActiveEffects(currentEffects, for: effectTarget)
        return events
    }

    private func effectCase(for keyword: Keyword, potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: return .poison(potency)
        }
    }

    mutating func logDoTDamage(
        _ result: (healthLost: Int, events: [ActionEvent]),
        keyword: Keyword,
        target: Combatant
    ) -> [ActionEvent] {
        var events = result.events
        guard result.healthLost > 0 else { return events }

        let event = nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: result.healthLost,
            keyword: keyword
        )
        events.append(event)
        appendLog("\(target.name) takes \(result.healthLost) \(keyword.rawValue) damage.")
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
        for index in remaining.indices {
            guard let handler = EffectHandlers.all[remaining[index].effect.kind] else { continue }
            let outcome = handler.tick(remaining[index], on: target, in: &self)
            events.append(contentsOf: outcome.events)
            if let updated = outcome.updatedStack {
                remaining[index] = updated
            }
            if outcome.removeAfter {
                toRemove.append(index)
            }
        }
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

    mutating func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        guard amount > 0 else { return (0, []) }

        let (healthLost, damageEvents) = applyDamage(amount, to: combatant)
        var events = damageEvents
        if healthLost > 0, let sourceActorID {
            events.append(contentsOf: applyLeechFromDamage(healthLost, sourceActorID: sourceActorID))
        }
        _ = keyword
        return (healthLost, events)
    }

    private mutating func applyPreventionBuildup(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> [ActionEvent] {
        guard amount > 0, roster.health(for: combatant) > 0 else { return [] }
        if hasActivePrevention(actor: combatant) { return [] }

        let baseThreshold = Double(maxHealth(for: combatant)) * 0.20
        let agilityResist = 1.0 + Double(combatant.primaryStats.agility) * 0.01
        let threshold = max(1, Int(ceil(baseThreshold * agilityResist)))
        var currentEffects = roster.activeEffects(for: combatant)

        let existingIndex = currentEffects.firstIndex { ae in
            if case let .preventionBuildup(k, _, _) = ae.effect, k == keyword { return true }
            return false
        }
        let existingAmount: Int = {
            guard let existingIndex,
                  case let .preventionBuildup(_, amt, _) = currentEffects[existingIndex].effect
            else { return 0 }
            return amt
        }()

        let newAmount = min(existingAmount + amount, threshold)
        var events: [ActionEvent] = []

        if newAmount >= threshold {
            if let existingIndex {
                currentEffects.remove(at: existingIndex)
            }
            let prevention = Effect.prevention(keyword, 1)
            let ae = ActiveEffect(
                id: nextEffectID,
                effect: prevention,
                remainingTicks: 1,
                sourceActorID: sourceActorID
            )
            nextEffectID += 1
            currentEffects.append(ae)
            roster.setActiveEffects(currentEffects, for: combatant)

            let actorName: String
            if let sourceActorID, let source = roster.combatant(for: sourceActorID) {
                actorName = source.name
            } else {
                actorName = combatant.name
            }
            let abilityName = keyword.statusAlias ?? keyword.rawValue
            events.append(nextEvent(
                kind: .effect,
                effectKind: .preventionTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword
            ))
        } else {
            let buildup = Effect.preventionBuildup(keyword, newAmount, threshold)
            if let existingIndex {
                currentEffects[existingIndex] = ActiveEffect(
                    id: currentEffects[existingIndex].id,
                    effect: buildup,
                    remainingTicks: currentEffects[existingIndex].remainingTicks,
                    sourceActorID: currentEffects[existingIndex].sourceActorID
                )
            } else {
                currentEffects.append(
                    ActiveEffect(
                        id: nextEffectID,
                        effect: buildup,
                        remainingTicks: 0,
                        sourceActorID: sourceActorID
                    )
                )
                nextEffectID += 1
            }
            roster.setActiveEffects(currentEffects, for: combatant)
        }

        return events
    }

    mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        guard damage > 0, let actor = roster.combatant(for: sourceActorID) else { return [] }
        let actorCombatant = actor.combatant

        let leechPct = roster.activeEffects(for: actorCombatant).reduce(0.0) { sum, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect { return sum + percent }
            return sum
        }
        guard leechPct > 0 else { return [] }

        let wisdomPercent = Double(actorCombatant.primaryStats.wisdom) * 0.001
        let totalPct = leechPct + wisdomPercent
        let restored = Int(ceil(Double(damage) * totalPct))
        guard restored > 0 else { return [] }

        applyHeal(restored, to: actorCombatant)
        return [
            nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: actorCombatant,
                amount: restored,
                keyword: .leech
            )
        ]
    }

    mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        var damageEvents: [ActionEvent] = []

        if amount > 0, roster.health(for: combatant) > 0, sourceActorID != nil {
            if Double.random(in: 0 ... 1, using: &rng) < combatant.primaryStats.dodgeChance {
                damageEvents.append(nextEvent(
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    actorName: combatant.name,
                    abilityName: "Dodge",
                    target: combatant,
                    amount: 0,
                    keyword: .dodge
                ))
                return (0, damageEvents)
            }
        }

        let statBonus: Int
        if let sourceActorID, let damageKeyword, let actor = roster.combatant(for: sourceActorID) {
            statBonus = actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
        } else {
            statBonus = 0
        }
        var remaining = amount + statBonus

        var currentEffects = roster.activeEffects(for: combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in currentEffects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(remaining, buffer)
                remaining -= absorbed
                if absorbed > 0 {
                    damageEvents.append(nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: combatant,
                        amount: absorbed,
                        keyword: keyword
                    ))

                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    currentEffects[index] = ActiveEffect(id: ae.id, effect: newEffect, remainingTicks: ae.remainingTicks)
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            currentEffects.remove(at: index)
        }

        let armorPct = currentEffects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        let toughnessPct = combatant.primaryStats.toughnessMitigationPct
        let combinedPct = max(0, min(1, armorPct + toughnessPct))
        if combinedPct > 0 {
            remaining = Int(ceil(Double(remaining) * (1 - combinedPct)))
        }

        roster.setActiveEffects(currentEffects, for: combatant)

        var runtime = runtime(for: combatant)
        let healthLost = runtime.takeRawDamage(remaining)
        updateRuntime(runtime)

        let dealt = amount + statBonus
        if dealt > 0,
           let damageKeyword,
           damageKeyword == .stun || damageKeyword == .freeze,
           roster.health(for: combatant) > 0 {
            damageEvents.append(contentsOf: applyPreventionBuildup(
                dealt,
                keyword: damageKeyword,
                to: combatant,
                sourceActorID: sourceActorID
            ))
        }

        return (healthLost, damageEvents)
    }

    mutating func applyHeal(_ amount: Int, to combatant: Combatant) {
        var runtime = runtime(for: combatant)
        runtime.heal(amount)
        updateRuntime(runtime)
    }

    mutating func nextEvent(
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind?,
        actorName: String,
        abilityName: String,
        target: Combatant,
        amount: Int,
        keyword: Keyword
    ) -> ActionEvent {
        nextEventID += 1
        return ActionEvent(
            id: nextEventID,
            kind: kind,
            effectKind: effectKind,
            actorName: actorName,
            abilityName: abilityName,
            targetID: target.id,
            targetName: target.name,
            amount: amount,
            keyword: keyword
        )
    }

    private mutating func appendLog(_ text: String) {
        log.append(LogEntry(id: nextLogEntryID, text: text))
        nextLogEntryID += 1
    }

    private mutating func appendDefeatLogIfNeeded() {
        guard isEnemyDefeated, !hasLoggedDefeat else { return }
        hasLoggedDefeat = true
        appendLog("\(enemy.name) is defeated.")
    }

    private mutating func appendPartyDefeatLogIfNeeded() {
        guard isPartyDefeated, !hasLoggedPartyDefeat else { return }
        hasLoggedPartyDefeat = true
        appendLog("Your party has been defeated by \(enemy.name).")
    }
}
