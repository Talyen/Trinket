import Foundation

/// Narrow mutation context passed to effect handlers. Owns the roster slice,
/// RNG, ID counters, and event stream for one handler dispatch.
struct BattleMutationContext: CombatPipelineHost {
    var roster: BattleRoster
    var rng: SeededRandomNumberGenerator
    var nextEffectID: Int
    var nextEventID: Int
    var events: [ActionEvent]
    var gold: Int
    let build: BattleCombatBuild

    func modifiers(for combatantID: String) -> CombatModifierProfile {
        build.modifiers(for: combatantID)
    }

    func health(of combatant: Combatant) -> Int {
        roster.health(for: combatant)
    }

    func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        roster.activeEffects(for: combatant)
    }

    mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        roster.setActiveEffects(effects, for: combatant)
    }

    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        build.adjustedOutgoingEffect(effect, sourceID: sourceID)
    }

    func shouldSkipImmediateDoT(
        potency: Int,
        keyword: Keyword,
        pairedDamageHits: [(Keyword, Int)]
    ) -> Bool {
        pairedDamageHits.contains(where: { $0 == (keyword, potency) })
    }

    mutating func addGold(_ amount: Int, sourceActorID: String) {
        gold += amount + modifiers(for: sourceActorID).goldGainedBonus
    }

    func runtime(for combatant: Combatant) -> CombatantRuntime {
        guard let runtime = roster.runtime(for: combatant) else {
            preconditionFailure("Unknown combatant id \(combatant.id)")
        }
        return runtime
    }

    mutating func updateRuntime(_ runtime: CombatantRuntime) {
        roster.update(runtime)
    }

    func hasActivePrevention(actor: Combatant) -> Bool {
        roster.activeEffects(for: actor).contains(where: {
            if case .prevention = $0.effect, $0.remainingTicks > 0 { return true }
            return false
        })
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

    mutating func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        CombatPipeline.applyDamage(
            amount,
            to: combatant,
            damageKeyword: damageKeyword,
            sourceActorID: sourceActorID,
            applyStatBonus: applyStatBonus,
            applyItemBonus: applyItemBonus,
            applyDodge: applyDodge,
            host: &self
        )
    }

    mutating func applyHeal(_ amount: Int, to combatant: Combatant, sourceActorID: String? = nil) {
        CombatPipeline.applyHeal(amount, to: combatant, sourceActorID: sourceActorID, host: &self)
    }

    mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        CombatPipeline.applyLeechFromDamage(damage, sourceActorID: sourceActorID, host: &self)
    }

    mutating func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?
    ) -> (healthLost: Int, events: [ActionEvent]) {
        CombatPipeline.applyDoTDamage(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            host: &self
        )
    }

    mutating func logDoTDamage(
        _ result: (healthLost: Int, events: [ActionEvent]),
        keyword: Keyword,
        target: Combatant
    ) -> [ActionEvent] {
        var collected = result.events
        guard result.healthLost > 0 else { return collected }

        let event = nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: result.healthLost,
            keyword: keyword
        )
        collected.append(event)
        return collected
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

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: logDoTDamage(
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
                    id: consumeNextEffectID(),
                    effect: effectCase(for: keyword, potency: boostedPotency),
                    remainingTicks: 0,
                    sourceActorID: sourceActorID
                )
            )
        }
        roster.setActiveEffects(currentEffects, for: effectTarget)
        return collected
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

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: logDoTDamage(
                applyDoTDamage(boostedPotency, keyword: .bleed, to: effectTarget, sourceActorID: sourceActorID),
                keyword: .bleed,
                target: effectTarget
            ))
        }

        var currentEffects = roster.activeEffects(for: effectTarget)
        currentEffects.append(
            ActiveEffect(
                id: consumeNextEffectID(),
                effect: .bleed(boostedPotency),
                remainingTicks: Effect.bleedDoTTickCount + modifiers(for: sourceActorID).bleedDurationBonus,
                sourceActorID: sourceActorID
            )
        )
        roster.setActiveEffects(currentEffects, for: effectTarget)
        return collected
    }

    private func effectCase(for keyword: Keyword, potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: return .poison(potency)
        }
    }
}

extension BattleMutationContext {
    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTicks: Int
    ) {
        var effects = activeEffects(for: target)
        effects.append(
            ActiveEffect(
                id: consumeNextEffectID(),
                effect: effect,
                remainingTicks: remainingTicks,
                sourceActorID: sourceID
            )
        )
        setActiveEffects(effects, for: target)
    }
}
