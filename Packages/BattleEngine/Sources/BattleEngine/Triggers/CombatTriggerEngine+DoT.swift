import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBleedDamage(
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) async {
        guard healthLost > 0, let sourceActorID,
              let caster = context.roster.combatant(for: sourceActorID),
              caster.id != target.id else { return }
        // Personal Bleed rewards require a living source.
        guard caster.isAlive else {
            return
        }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if triggers.onBleedDamageNextBasicGuaranteedCrit {
            context.roster.mutateRuntime(for: caster.combatant) { $0.talents.pending.basicGuaranteedCritical = true }
        }
        if triggers.onBleedDamageNextBasicCritBonus > 0 {
            context.roster.mutateRuntime(for: caster.combatant) {
                $0.talents.pending.basicCriticalBonus = max($0.talents.pending.basicCriticalBonus, triggers.onBleedDamageNextBasicCritBonus)
            }
        }
        if triggers.onBleedDamageHealSelf > 0 {
            _ = await HealingEngine.resolveHeal(
                HealRequest(amount: triggers.onBleedDamageHealSelf, target: caster.combatant, sourceActorID: sourceActorID),
                in: &context,
            )
        }
        if triggers.bleedConsumesPoison, context.roster.health(for: target) > 0 {
            let poisonPotency = DoTApplicator.consume(.poison, upTo: healthLost, on: target, in: &context)
            if poisonPotency > 0 {
                _ = await DoTDamage.resolveDamage(
                    basePotency: poisonPotency,
                    keyword: .poison,
                    target: target,
                    sourceActorID: sourceActorID,
                    operation: .resolvedPeriodic,
                    in: &context,
                )
            }
        }
    }

    static func afterDoTTick(
        keyword: Keyword,
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) async {
        guard let sourceActorID else { return }
        let sourceTriggers = context.modifiers(for: sourceActorID).triggers

        if keyword == .burn {
            if sourceTriggers.onBurnTickHolyDamage > 0 {
                _ = await context.dealReactionDamage(
                    sourceTriggers.onBurnTickHolyDamage, to: target, keyword: .holy, sourceActorID: sourceActorID,
                )
            }
            let detonateChance = chanceOrGuaranteed(
                sourceTriggers.onBurnDamageDetonateBleedChancePercent,
                guaranteed: sourceTriggers.onBurnDamageDetonateBleed,
            )
            if detonateChance > 0, healthLost > 0,
               BattleChance.succeeds(probability: min(1, detonateChance), using: &context.rng) {
                await detonateBleed(on: target, sourceActorID: sourceActorID, in: &context)
            }
        }
    }

    static func afterPoisonDamage(
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) async {
        guard healthLost > 0, let sourceActorID,
              let caster = context.roster.combatant(for: sourceActorID) else { return }
        let sourceTriggers = context.modifiers(for: caster.id).triggers
        guard sourceTriggers.poisonThresholdStunAmount > 0,
              target.role == .enemy,
              context.roster.health(for: target) > 0,
              context.roster.activeEffects(for: target).contains(where: {
                  $0.effect.kind == .poison && ($0.effect.potency ?? 0) >= sourceTriggers.poisonThresholdStunAmount
              })
        else { return }
        let chance = chanceOrGuaranteed(sourceTriggers.poisonStunChancePercent, guaranteed: true)
        guard BattleChance.succeeds(probability: min(1, chance), using: &context.rng) else { return }
        await ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: target, in: context),
            keyword: .stun,
            to: target,
            sourceActorID: caster.id,
            applyFightPacing: false,
            in: &context,
        )
    }

    static func restoreManaFromBurnDamage(
        sourceActorID: String,
        sourceTriggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard let caster = context.roster.combatant(for: sourceActorID),
              let participant = context.roster.participant(for: caster.combatant)
        else { return }
        let already = context.turnCadence.burnManaRestored[participant, default: 0]
        let cap = sourceTriggers.onBurnDamageRestoreManaPerTurnCap
        guard cap <= 0 || already < cap else { return }
        let toRestore = min(
            sourceTriggers.onBurnDamageRestoreManaFlat,
            cap > 0 ? cap - already : sourceTriggers.onBurnDamageRestoreManaFlat,
        )
        let restored = context.restoreMana(toRestore, to: caster.combatant, maximumGain: cap > 0 ? cap - already : nil)
        consumeManaOverflowTalents(for: caster.combatant, restoredMana: restored > 0, in: &context)
        guard restored > 0 else { return }
        context.turnCadence.burnManaRestored[participant, default: 0] += restored
        context.nextEvent(
            kind: .effect(.resourceGain),
            source: .init(caster),
            abilityName: triggerAbilityName(
                .onBurnDamageRestoreManaFlat,
                for: caster.combatant,
                fallback: "Pyromancer's Spark",
                in: context,
            ),
            target: caster.combatant,
            amount: restored,
            keyword: .mana,
        )
        await afterGainMana(by: caster.combatant, in: &context)
    }

    static func detonateBleedAndPoison(
        on target: Combatant,
        sourceActorID: String,
        includePoison: Bool = true,
        in context: inout BattleState,
    ) async {
        guard context.resolution.depth(.detonation) == 0 else { return }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }

        guard context.roster.activeEffects(for: target).contains(where: {
            $0.effect.isBleed && $0.remainingTurns > 0 || includePoison && $0.effect.kind == .poison
        }) else { return }
        var bleeds: [ActiveEffect] = []
        var poisons: [ActiveEffect] = []
        context.roster.mutateEffects(for: target) { effects in
            effects.removeAll { active in
                if active.effect.isBleed {
                    if active.remainingTurns > 0 {
                        bleeds.append(active)
                    }
                    return true
                }
                if includePoison, active.effect.kind == .poison {
                    poisons.append(active)
                    return true
                }
                return false
            }
        }

        await Self.detonateBleedStacks(bleeds, on: target, sourceActorID: sourceActorID, in: &context)

        for active in poisons {
            await DecayingDoTDetonation.resolve(active, factor: 1, target: target, sourceActorID: sourceActorID, in: &context)
        }
    }

    static func detonateBleedStacks(
        _ bleeds: [ActiveEffect],
        on target: Combatant,
        sourceActorID: String,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) async {
        if context.modifiers(for: sourceActorID).triggers.redline,
           bleeds.contains(where: { $0.remainingTurns > 0 && ($0.effect.potency ?? 0) > 0 }) {
            context.roster.mutateRuntime(forID: sourceActorID) { $0.talents.history.preparations.insert(.bleedDamage) }
        }

        for active in bleeds {
            guard case let .bleed(potency) = active.effect else { continue }
            let extends = active.sourceActorID.map { context.modifiers(for: $0).triggers.bleedHalvesAfterExpiration } == true
            let damageSourceID = extends ? (active.sourceActorID ?? sourceActorID) : sourceActorID
            for _ in 0 ..< active.remainingTurns {
                guard context.roster.health(for: target) > 0 else { break }
                _ = await DoTDamage.resolveDamage(
                    basePotency: potency,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: damageSourceID,
                    provenance: provenance,
                    in: &context,
                )
            }
            var tail = extends ? potency / 2 : 0
            while tail > 0, context.roster.health(for: target) > 0 {
                _ = await DoTDamage.resolveDamage(
                    basePotency: tail,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: damageSourceID,
                    provenance: provenance,
                    in: &context,
                )
                tail /= 2
            }
        }
    }
}
