import Foundation

/// Damage, healing, leech, and prevention-buildup rules.
enum CombatPipeline {
    private static func maxHealth(for combatant: Combatant) -> Int {
        combatant.maxHealth + combatant.primaryStats.toughness
    }

    static func applyDoTDamage<H: CombatPipelineHost>(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        host: inout H
    ) -> (healthLost: Int, events: [ActionEvent]) {
        guard amount > 0 else { return (0, []) }

        let (healthLost, damageEvents) = applyDamage(
            amount,
            to: combatant,
            damageKeyword: keyword,
            sourceActorID: sourceActorID,
            applyStatBonus: false,
            applyDodge: false,
            host: &host
        )
        var events = damageEvents
        if healthLost > 0, let sourceActorID {
            events.append(contentsOf: applyLeechFromDamage(healthLost, sourceActorID: sourceActorID, host: &host))
        }
        return (healthLost, events)
    }

    static func applyPreventionBuildup<H: CombatPipelineHost>(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        host: inout H
    ) -> [ActionEvent] {
        guard amount > 0, host.roster.health(for: combatant) > 0 else { return [] }
        if host.hasActivePrevention(actor: combatant) { return [] }

        let baseThreshold = Double(maxHealth(for: combatant)) * 0.20
        let agilityResist = 1.0 + Double(combatant.primaryStats.agility) * 0.01
        let threshold = max(1, Int(ceil(baseThreshold * agilityResist)))
        var currentEffects = host.roster.activeEffects(for: combatant)

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
                id: host.nextEffectID,
                effect: prevention,
                remainingTicks: 1,
                sourceActorID: sourceActorID
            )
            host.nextEffectID += 1
            currentEffects.append(ae)
            host.roster.setActiveEffects(currentEffects, for: combatant)

            let actorName: String
            if let sourceActorID, let source = host.roster.combatant(for: sourceActorID) {
                actorName = source.name
            } else {
                actorName = combatant.name
            }
            let abilityName = keyword.statusAlias ?? keyword.rawValue
            events.append(host.nextEvent(
                kind: .effect,
                effectKind: .preventionTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword,
                appliedEffectSummaries: [],
                milestone: nil
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
                        id: host.nextEffectID,
                        effect: buildup,
                        remainingTicks: 0,
                        sourceActorID: sourceActorID
                    )
                )
                host.nextEffectID += 1
            }
            host.roster.setActiveEffects(currentEffects, for: combatant)
        }

        return events
    }

    static func applyLeechFromDamage<H: CombatPipelineHost>(
        _ damage: Int,
        sourceActorID: String,
        host: inout H
    ) -> [ActionEvent] {
        guard damage > 0, let actor = host.roster.combatant(for: sourceActorID) else { return [] }
        let actorCombatant = actor.combatant

        let leechPct = host.roster.activeEffects(for: actorCombatant).reduce(0.0) { sum, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect { return sum + percent }
            return sum
        }
        guard leechPct > 0 else { return [] }

        let wisdomPercent = Double(actorCombatant.primaryStats.wisdom) * 0.001
        let totalPct = leechPct + wisdomPercent
        var restored = Int(ceil(Double(damage) * totalPct))
        restored += host.modifiers(for: sourceActorID).leechHealingBonus
        guard restored > 0 else { return [] }

        applyHeal(restored, to: actorCombatant, sourceActorID: nil, host: &host)
        return [
            host.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: actorCombatant,
                amount: restored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil
            )
        ]
    }

    static func applyDamage<H: CombatPipelineHost>(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        host: inout H
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        var damageEvents: [ActionEvent] = []

        if applyDodge, amount > 0, host.roster.health(for: combatant) > 0, sourceActorID != nil {
            if Double.random(in: 0 ... 1, using: &host.rng) < combatant.primaryStats.dodgeChance {
                damageEvents.append(host.nextEvent(
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    actorName: combatant.name,
                    abilityName: "Dodge",
                    target: combatant,
                    amount: 0,
                    keyword: .dodge,
                    appliedEffectSummaries: [],
                    milestone: nil
                ))
                return (0, damageEvents)
            }
        }

        let statBonus: Int
        let itemBonus: Int
        if let sourceActorID, let damageKeyword, let actor = host.roster.combatant(for: sourceActorID) {
            statBonus = applyStatBonus ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword) : 0
            itemBonus = applyItemBonus ? host.modifiers(for: sourceActorID).damageDealtBonus(for: damageKeyword) : 0
        } else {
            statBonus = 0
            itemBonus = 0
        }
        var remaining = amount + statBonus + itemBonus

        var currentEffects = host.roster.activeEffects(for: combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in currentEffects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(remaining, buffer)
                remaining -= absorbed
                if absorbed > 0 {
                    damageEvents.append(host.nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: combatant,
                        amount: absorbed,
                        keyword: keyword,
                        appliedEffectSummaries: [],
                        milestone: nil
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

        if let damageKeyword, remaining > 0 {
            let reduction = host.modifiers(for: combatant.id).damageTakenReduction(for: damageKeyword)
            if reduction > 0 {
                remaining = Int(ceil(Double(remaining) * (1 - reduction)))
            }
        }

        host.roster.setActiveEffects(currentEffects, for: combatant)

        var runtime = host.runtime(for: combatant)
        let healthLost = runtime.takeRawDamage(remaining)
        host.updateRuntime(runtime)

        let dealt = amount + statBonus + itemBonus
        if dealt > 0,
           let damageKeyword,
           damageKeyword == .stun || damageKeyword == .freeze,
           host.roster.health(for: combatant) > 0 {
            damageEvents.append(contentsOf: applyPreventionBuildup(
                dealt,
                keyword: damageKeyword,
                to: combatant,
                sourceActorID: sourceActorID,
                host: &host
            ))
        }

        return (healthLost, damageEvents)
    }

    static func applyHeal<H: CombatPipelineHost>(
        _ amount: Int,
        to combatant: Combatant,
        sourceActorID: String?,
        host: inout H
    ) {
        let bonus = sourceActorID.map { host.modifiers(for: $0).healthRestoredBonus } ?? 0
        var runtime = host.runtime(for: combatant)
        runtime.heal(amount + bonus)
        host.updateRuntime(runtime)
    }
}

extension BattleState {
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

    mutating func applyLeechFromDamage(_ damage: Int, sourceActorID: String) -> [ActionEvent] {
        CombatPipeline.applyLeechFromDamage(damage, sourceActorID: sourceActorID, host: &self)
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
}
