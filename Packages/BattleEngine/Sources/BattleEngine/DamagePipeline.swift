import Foundation
import TrinketCore
import TrinketContent

/// Execution phase for a damage pipeline step. Future RNG mechanics (crit,
/// block) register in `.stochastic`; leech and CC buildup stay in `.post`.
package enum DamagePhase: Sendable {
    /// Rolls battle RNG and may short-circuit the pipeline (dodge today).
    case stochastic
    /// Deterministic damage math and HP subtraction.
    case resolution
    /// Side effects after final damage is known (leech, control-meter buildup).
    case post
}

/// Ordered registry and runner for damage resolution steps.
package enum DamagePipeline {
    private struct Step {
        let name: String
        let phase: DamagePhase
        let apply: (inout DamageResolutionState, inout BattleEngineContext) -> Void
    }

    private static let steps: [Step] = [
        Step(name: "DodgeGate", phase: .stochastic, apply: applyDodgeGate),
        Step(name: "CriticalGate", phase: .stochastic, apply: applyCriticalGate),
        Step(name: "DamageBonus", phase: .resolution, apply: applyDamageBonus),
        Step(name: "MarkedBonus", phase: .resolution, apply: applyMarkedBonus),
        Step(name: "Mitigation", phase: .resolution, apply: applyMitigation),
        Step(name: "ItemReduction", phase: .resolution, apply: applyItemReduction),
        Step(name: "ShieldAbsorption", phase: .resolution, apply: applyShieldAbsorption),
        Step(name: "CriticalMultiply", phase: .resolution, apply: applyCriticalMultiply),
        Step(name: "TakeDamage", phase: .resolution, apply: applyTakeDamage),
        Step(name: "MarkedConsume", phase: .resolution, apply: applyMarkedConsume),
        Step(name: "DeathsDoor", phase: .resolution, apply: applyDeathsDoor),
        Step(name: "Leech", phase: .post, apply: applyLeech),
        Step(name: "ControlMeter", phase: .post, apply: applyControlMeter),
        Step(name: "ReactiveOnHit", phase: .post, apply: applyReactiveOnHit)
    ]

    public static var canonicalNames: [String] {
        steps.map(\.name)
    }

    public static func run(
        state: inout DamageResolutionState,
        in context: inout BattleEngineContext,
        onStep: ((String) -> Void)? = nil
    ) {
        for step in steps {
            if state.isRetaliation, step.name == "ReactiveOnHit" {
                continue
            }
            onStep?(step.name)
            step.apply(&state, &context)
            if step.phase == .stochastic, state.isDodged {
                return
            }
        }
    }

    /// Test helper: records step names actually executed for a damage request.
    package static func executedStepNames(
        for request: DamageRequest,
        in context: inout BattleEngineContext
    ) -> [String] {
        guard request.amount > 0 else { return [] }

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

        var executed: [String] = []
        run(state: &state, in: &context) { executed.append($0) }
        return executed
    }

    // MARK: - Stochastic steps

    private static func applyDodgeGate(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.applyDodge,
              state.amount > 0,
              context.roster.health(for: state.combatant) > 0,
              state.sourceActorID != nil
        else { return }
        let chance = dodgeChance(for: state, in: context)
        if Double.random(in: 0 ... 1, using: &context.rng) < chance {
            state.damageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .dodgeApplied,
                actorName: state.combatant.name,
                abilityName: "Dodge",
                target: state.combatant,
                amount: 0,
                keyword: .dodge,
                appliedEffectSummaries: [],
                milestone: nil
            ))
            state.isDodged = true
        }
    }

    private static func dodgeChance(
        for state: DamageResolutionState,
        in context: BattleEngineContext
    ) -> Double {
        var chance = state.combatant.primaryStats.dodgeChance
        let profile = context.modifiers(for: state.combatant.id)
        chance += profile.dodgeChanceBonus
        if state.damageKeyword == .physical {
            chance += profile.physicalDodgeChanceBonus
        }
        return min(0.75, chance)
    }

    private static func applyCriticalGate(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.amount > 0,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let actor = context.roster.combatant(for: sourceActorID)
        else { return }

        var chance = actor.primaryStats.criticalChance(for: damageKeyword)
        chance += state.abilityCriticalChanceBonus

        let sourceEffects = context.activeEffects(for: actor.combatant)
        for active in sourceEffects {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }

        if state.guaranteedCriticalIfEnemyBuffed,
           context.activeEffects(for: state.combatant).contains(where: { $0.effect.isRemovableBuff }) {
            chance = 1.0
        }

        chance = min(0.75, chance)
        guard Double.random(in: 0 ... 1, using: &context.rng) < chance else { return }

        state.isCritical = true
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .criticalApplied,
            actorName: actor.name,
            abilityName: "Critical",
            target: state.combatant,
            amount: 0,
            keyword: damageKeyword
        ))
    }

    // MARK: - Resolution steps

    private static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
                : 0
            state.itemBonus = state.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if state.qualifiesForAmbush,
               let runtime = context.roster.runtime(for: actor.combatant),
               !runtime.hasTriggeredAmbush {
                let ambushBonus = context.modifiers(for: sourceActorID).ambushBonusDamage
                if ambushBonus > 0 {
                    state.itemBonus += ambushBonus
                    context.roster.mutateRuntime(for: actor.combatant) { $0.hasTriggeredAmbush = true }
                }
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }

    private static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleEngineContext
    ) -> Int {
        var bonus = context.modifiers(for: sourceActorID).damageDealtBonus(for: keyword)
        if sourceActorID == context.build.petID {
            bonus += context.build.heroModifiers.petDamageDealtBonus
        }
        return bonus
    }

    private static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.sourceActorID != nil else { return }
        let effects = context.roster.activeEffects(for: state.combatant)
        guard effects.contains(where: { if case .marked = $0.effect { return true }; return false }) else {
            return
        }

        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.markedBonusApplied = true
    }

    private static func applyMitigation(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        var armorPct = effects.reduce(0.0) { sum, ae in
            if case let .mitigation(_, p, _) = ae.effect { return sum + p }
            return sum
        }
        armorPct += profile.passiveArmorPercent
        if let runtime = context.roster.runtime(for: state.combatant),
           runtime.mitigationShredUntilTick > context.tickCount {
            armorPct *= runtime.mitigationShredMultiplier
        }
        if profile.armorEffectivenessPenaltyPercent > 0 {
            armorPct *= max(0, 1 - profile.armorEffectivenessPenaltyPercent)
        }
        let toughnessPct = state.combatant.primaryStats.toughnessMitigationPct
        let combinedPct = max(0, min(1, armorPct + toughnessPct))
        if combinedPct > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - combinedPct)))
        }
    }

    private static func applyItemReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let profile = context.modifiers(for: state.combatant.id)
        let reduction = profile.damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 + vulnerability)))
        }
        state.buildupDamage = state.remaining
    }

    private static func applyShieldAbsorption(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: state.combatant)
        var shieldIndexes: [Int] = []

        for (index, ae) in effects.enumerated() {
            if case let .shield(keyword, buffer, _) = ae.effect {
                let absorbed = min(state.remaining, buffer)
                state.remaining -= absorbed
                if absorbed > 0 {
                    state.damageEvents.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .shieldAbsorbed,
                        actorName: keyword.rawValue,
                        abilityName: keyword.rawValue,
                        target: state.combatant,
                        amount: absorbed,
                        keyword: keyword,
                        appliedEffectSummaries: [],
                        milestone: nil
                    ))
                    let newBuffer = buffer - absorbed
                    let newEffect: Effect = .shield(keyword, newBuffer, ae.effect.durationTicks)
                    effects[index] = ActiveEffect(
                        id: ae.id,
                        effect: newEffect,
                        remainingTicks: ae.remainingTicks,
                        sourceActorID: ae.sourceActorID
                    )
                    if newBuffer <= 0 {
                        shieldIndexes.append(index)
                    }
                }
            }
        }

        for index in shieldIndexes.reversed() {
            effects.remove(at: index)
        }
        state.activeEffects = effects
    }

    private static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        _ = context
        guard state.isCritical, state.remaining > 0 else { return }
        state.remaining *= 2
        state.dealt = state.remaining
    }

    private static func applyTakeDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        context.roster.setActiveEffects(state.activeEffects, for: state.combatant)
        var lost = 0
        context.roster.mutateRuntime(for: state.combatant) { lost = $0.takeRawDamage(state.remaining) }
        state.healthLost = lost
    }

    private static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.markedBonusApplied, state.healthLost > 0 else { return }

        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        effects.remove(at: index)
        context.roster.setActiveEffects(effects, for: state.combatant)
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical
        ))
    }

    private static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }

    // MARK: - Post steps

    private static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.healthLost > 0,
              let sourceActorID = state.sourceActorID,
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            in: &context
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
    }

    private static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.healthLost > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            state.healthLost,
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            in: &context
        ))
    }

    private static func applyReactiveOnHit(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        guard state.healthLost > 0, let sourceActorID = state.sourceActorID else { return }
        guard let attacker = context.roster.combatant(for: sourceActorID) else { return }

        if let damageKeyword = state.damageKeyword {
            EnemyTraitEngine.applyShieldErosion(
                keyword: damageKeyword,
                to: state.combatant,
                context: &context
            )
            EnemyTraitEngine.applyMitigationShred(
                keyword: damageKeyword,
                to: state.combatant,
                context: &context
            )
        }

        state.damageEvents.append(contentsOf: EnemyTraitEngine.traitThornsDamage(
            damageTaken: state.healthLost,
            defender: state.combatant,
            attackerID: sourceActorID,
            in: &context
        ))

        let activeEffects = context.roster.activeEffects(for: state.combatant)
        for active in activeEffects {
            switch active.effect {
            case let .thorns(keyword, amount, _):
                guard amount > 0 else { continue }
                let events = context.resolveDamage(
                    DamageRequest(
                        amount: amount,
                        target: attacker.combatant,
                        keyword: keyword,
                        sourceActorID: state.combatant.id,
                        options: DamageOptions(isRetaliation: true)
                    )
                ).events
                var thornsEvents = events
                if let lastIndex = thornsEvents.indices.last {
                    var event = thornsEvents[lastIndex]
                    thornsEvents[lastIndex] = ActionEvent(
                        id: event.id,
                        kind: event.kind,
                        effectKind: .thornsTriggered,
                        actorName: state.combatant.name,
                        abilityName: "Thorns",
                        targetID: event.targetID,
                        targetName: event.targetName,
                        amount: event.amount,
                        keyword: event.keyword,
                        appliedEffectSummaries: event.appliedEffectSummaries,
                        milestone: event.milestone
                    )
                }
                state.damageEvents.append(contentsOf: thornsEvents)
            case let .restoreManaOnHit(amount, _):
                let restored = context.restoreMana(amount, to: state.combatant, sourceActorID: state.combatant.id)
                guard restored > 0 else { continue }
                state.damageEvents.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .manaShieldTriggered,
                    actorName: state.combatant.name,
                    abilityName: "Mana Shield",
                    target: state.combatant,
                    amount: restored,
                    keyword: .mana
                ))
            default:
                continue
            }
        }
    }
}
