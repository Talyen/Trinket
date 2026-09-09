import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBleedDamage(
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard healthLost > 0, let sourceActorID,
              let caster = context.roster.combatant(for: sourceActorID), caster.isAlive,
              caster.id != target.id else { return [] }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if triggers.onBleedDamageNextBasicGuaranteedCrit {
            context.roster.mutateRuntime(for: caster.combatant) { $0.pendingBasicGuaranteedCrit = true }
        }
        if triggers.onBleedDamageNextBasicCritBonus > 0 {
            context.roster.mutateRuntime(for: caster.combatant) {
                $0.pendingBasicCritBonus = max($0.pendingBasicCritBonus, triggers.onBleedDamageNextBasicCritBonus)
            }
        }
        var events: [ActionEvent] = []
        if triggers.onBleedDamageHealSelf > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(amount: triggers.onBleedDamageHealSelf, target: caster.combatant, sourceActorID: sourceActorID),
                in: &context,
            ).events)
        }
        if triggers.bleedConsumesPoison, context.roster.health(for: target) > 0 {
            let poisonPotency = DoTApplicator.consume(.poison, upTo: healthLost, on: target, in: &context)
            if poisonPotency > 0 {
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: poisonPotency,
                    keyword: .poison,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context,
                ).events)
            }
        }
        return events
    }

    static func afterDoTTick(
        keyword: Keyword,
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let sourceActorID else { return [] }
        let sourceTriggers = context.modifiers(for: sourceActorID).triggers
        var events: [ActionEvent] = []
        if keyword == .burn {
            events.append(contentsOf: DoTMirrorCascade.resolve(
                keyword: .burn,
                initialHealthLost: healthLost,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            ))
            if sourceTriggers.onBurnTickHolyDamage > 0 {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: sourceTriggers.onBurnTickHolyDamage,
                        target: target,
                        keyword: .holy,
                        sourceActorID: sourceActorID,
                        options: .reaction(),
                    ),
                ).events)
            }
            let detonateChance = sourceTriggers.onBurnDamageDetonateBleedChancePercent > 0
                ? sourceTriggers.onBurnDamageDetonateBleedChancePercent
                : (sourceTriggers.onBurnDamageDetonateBleed ? 1 : 0)
            if detonateChance > 0, healthLost > 0,
               BattleChance.succeeds(probability: min(1, detonateChance), using: &context.rng) {
                events.append(contentsOf: detonateBleed(
                    on: target,
                    sourceActorID: sourceActorID,
                    in: &context,
                ))
            }
            if sourceTriggers.onBurnDamageRestoreManaFlat > 0,
               healthLost >= sourceTriggers.burnDamageManaRestoreThreshold {
                events.append(contentsOf: restoreManaFromBurnTick(
                    sourceActorID: sourceActorID,
                    sourceTriggers: sourceTriggers,
                    in: &context,
                ))
            }
        }
        return events
    }

    static func afterPoisonDamage(
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard healthLost > 0, let sourceActorID,
              let caster = context.roster.combatant(for: sourceActorID) else { return [] }
        let leechPercent = context.modifiers(for: sourceActorID).triggers.poisonDamageLeechPercent
        guard leechPercent > 0 else { return [] }
        let leech = CombatRounding.scaled(healthLost, multiplier: leechPercent)
        guard leech > 0 else { return [] }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: leech, target: caster.combatant, sourceActorID: sourceActorID, origin: .leech, logAs: .silent),
            in: &context,
        )
        var events = outcome.events
        if outcome.healthRestored > 0 {
            events.append(contentsOf: afterLeech(by: caster.combatant, target: target, in: &context))
        }
        return events
    }

    static func afterDecayingDoTTurn(
        keyword: Keyword,
        nextPotency: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard keyword == .poison,
              let sourceActorID,
              let sourceTriggers = Optional(context.modifiers(for: sourceActorID).triggers),
              sourceTriggers.poisonThresholdStunAmount > 0,
              nextPotency >= sourceTriggers.poisonThresholdStunAmount,
              target.role == .enemy,
              context.roster.health(for: target) > 0
        else { return [] }
        let chance = sourceTriggers.poisonStunChancePercent > 0 ? sourceTriggers.poisonStunChancePercent : 1
        guard BattleChance.succeeds(probability: min(1, chance), using: &context.rng) else { return [] }
        return ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: target, in: context),
            keyword: .stun,
            to: target,
            sourceActorID: sourceActorID,
            applyFightPacing: false,
            in: &context,
        )
    }

    private static func restoreManaFromBurnTick(
        sourceActorID: String,
        sourceTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let caster = context.roster.combatant(for: sourceActorID),
              let participant = context.roster.participant(for: caster.combatant)
        else { return [] }
        let already = context.turnCadence.burnManaRestored[participant, default: 0]
        let cap = sourceTriggers.onBurnDamageRestoreManaPerTurnCap
        guard cap <= 0 || already < cap else { return [] }
        let toRestore = min(
            sourceTriggers.onBurnDamageRestoreManaFlat,
            cap > 0 ? cap - already : sourceTriggers.onBurnDamageRestoreManaFlat,
        )
        let restored = context.restoreMana(toRestore, to: caster.combatant)
        guard restored > 0 else { return [] }
        context.turnCadence.burnManaRestored[participant, default: 0] += restored
        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: caster.name,
            abilityName: triggerAbilityName(
                "onBurnDamageRestoreManaFlat",
                for: caster.combatant,
                fallback: "Pyromancer's Spark",
                in: context,
            ),
            target: caster.combatant,
            amount: restored,
            keyword: .mana,
        )]
        events.append(contentsOf: afterGainMana(by: caster.combatant, in: &context))
        return events
    }

    static func detonateBleedAndPoison(
        on target: Combatant,
        sourceActorID: String,
        includePoison: Bool = true,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.resolution.depth(.detonation) == 0 else { return [] }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }

        let currentEffects = context.roster.activeEffects(for: target)
        let bleeds = currentEffects.filter { $0.effect.isBleed && $0.remainingTurns > 0 }
        let poisonPotency = includePoison ? currentEffects.reduce(0) { total, active in
            guard case let .poison(potency) = active.effect else { return total }
            return total + potency
        } : 0
        guard !bleeds.isEmpty || poisonPotency > 0 else { return [] }

        context.roster.setActiveEffects(
            currentEffects.filter { active in
                if active.effect.isBleed {
                    return false
                }
                if includePoison, case .poison = active.effect {
                    return false
                }
                return true
            },
            for: target,
        )

        var events: [ActionEvent] = []
        events.append(contentsOf: Self.detonateBleedStacks(bleeds, on: target, sourceActorID: sourceActorID, in: &context))

        var potency = poisonPotency
        while potency > 0, context.roster.health(for: target) > 0 {
            potency -= Effect.poisonDecayAmount(for: potency)
            guard potency > 0 else { break }
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: potency,
                keyword: .poison,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            ).events)
        }
        return events
    }

    static func detonateBleedStacks(
        _ bleeds: [ActiveEffect],
        on target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if context.modifiers(for: sourceActorID).triggers.redline,
           bleeds.contains(where: { $0.remainingTurns > 0 && ($0.effect.potency ?? 0) > 0 }) {
            context.heroTalents.history[sourceActorID, default: HeroTalentHistory()].preparations.insert(.bleedDamage)
        }
        var events: [ActionEvent] = []
        for active in bleeds {
            guard case let .bleed(potency) = active.effect else { continue }
            let extends = active.sourceActorID.map { context.modifiers(for: $0).triggers.bleedHalvesAfterExpiration } == true
            let damageSourceID = extends ? (active.sourceActorID ?? sourceActorID) : sourceActorID
            for _ in 0 ..< active.remainingTurns {
                guard context.roster.health(for: target) > 0 else { break }
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: potency,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: damageSourceID,
                    in: &context,
                ).events)
            }
            var tail = extends ? potency / 2 : 0
            while tail > 0, context.roster.health(for: target) > 0 {
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: tail,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: damageSourceID,
                    in: &context,
                ).events)
                tail /= 2
            }
        }
        return events
    }

    static func applyDoT(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        application: DoTApplication = .reaction,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        switch keyword {
        case .bleed:
            DoTApplicator.applyBleed(
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                application: application,
                in: &context,
            )
        default:
            context.applyDecayingDoT(
                keyword: keyword,
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                application: application,
            )
        }
    }
}
