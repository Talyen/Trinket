import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Per-tick Burn/Poison reactions after the DoT damage itself has resolved.
    static func afterDoTTick(
        keyword: Keyword,
        healthLost: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState
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
                in: &context
            ))
            if sourceTriggers.onBurnTickHolyDamage > 0 {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: sourceTriggers.onBurnTickHolyDamage,
                        target: target,
                        keyword: .holy,
                        sourceActorID: sourceActorID,
                        options: .flatReaction
                    )
                ).events)
            }
            if sourceTriggers.onBurnDamageDetonateBleed, healthLost > 0 {
                events.append(contentsOf: detonateBleed(
                    on: target,
                    sourceActorID: sourceActorID,
                    in: &context
                ))
            }
            if sourceTriggers.onBurnDamageRestoreManaFlat > 0,
               healthLost >= sourceTriggers.burnDamageManaRestoreThreshold {
                events.append(contentsOf: restoreManaFromBurnTick(
                    sourceActorID: sourceActorID,
                    sourceTriggers: sourceTriggers,
                    in: &context
                ))
            }
        }
        if keyword == .poison,
           sourceTriggers.poisonDamageLeechPercent > 0,
           healthLost > 0,
           let caster = context.roster.combatant(for: sourceActorID) {
            let leech = CombatRounding.scaled(healthLost, multiplier: sourceTriggers.poisonDamageLeechPercent)
            if leech > 0 {
                events.append(contentsOf: HealingEngine.resolveHeal(
                    HealRequest(amount: leech, target: caster.combatant, sourceActorID: sourceActorID),
                    in: &context
                ).events)
            }
        }
        return events
    }

    /// End-of-turn Poison reactions after every tick has resolved (Paralysis).
    static func afterDecayingDoTTurn(
        keyword: Keyword,
        nextPotency: Int,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard keyword == .poison,
              let sourceTriggers = sourceActorID.map({ context.modifiers(for: $0).triggers }),
              sourceTriggers.poisonThresholdStunAmount > 0,
              nextPotency >= sourceTriggers.poisonThresholdStunAmount,
              target.role == .enemy,
              context.roster.health(for: target) > 0
        else { return [] }
        return ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: target, in: context),
            keyword: .stun,
            to: target,
            sourceActorID: sourceActorID,
            applyFightPacing: false,
            in: &context
        )
    }

    private static func restoreManaFromBurnTick(
        sourceActorID: String,
        sourceTriggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let already = context.burnManaRestoredThisTurn[sourceActorID, default: 0]
        let cap = sourceTriggers.onBurnDamageRestoreManaPerTurnCap
        guard cap <= 0 || already < cap,
              let caster = context.roster.combatant(for: sourceActorID)
        else { return [] }
        let toRestore = min(
            sourceTriggers.onBurnDamageRestoreManaFlat,
            cap > 0 ? cap - already : sourceTriggers.onBurnDamageRestoreManaFlat
        )
        let restored = context.restoreMana(toRestore, to: caster.combatant)
        guard restored > 0 else { return [] }
        context.burnManaRestoredThisTurn[sourceActorID, default: 0] += restored
        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: caster.name,
            abilityName: triggerAbilityName(
                "onBurnDamageRestoreManaFlat",
                for: caster.combatant,
                fallback: "Pyromancer's Spark",
                in: context
            ),
            target: caster.combatant,
            amount: restored,
            keyword: .mana
        )]
        events.append(contentsOf: afterGainMana(by: caster.combatant, in: &context))
        return events
    }
}
