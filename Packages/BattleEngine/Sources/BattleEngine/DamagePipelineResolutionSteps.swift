import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    // MARK: - Resolution steps

    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        applyStatAndItemBonus(to: &state, in: &context)
        applyPercentBonus(to: &state, in: &context)
        applyDodgeEmpoweredBonuses(to: &state, in: &context)
        applyStunnedAndTalentMultipliers(to: &state, in: &context)
        applyOneShotEmpowers(to: &state, in: &context)
        applyEnemyOutgoingReductions(to: &state, in: &context)
        state.dealt = state.remaining
    }

    /// Stat-keyword and outgoing-item bonus computation.
    private static func applyStatAndItemBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? CombatRounding.scaled(state.amount, multiplier: actor.primaryStats.statDamageBonusPercent(keyword: damageKeyword))
                : 0
            state.itemBonus = state.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if state.isAttackHit,
               var runtime = context.roster.runtime(for: actor.combatant) {
                let profile = context.modifiers(for: sourceActorID)
                if !runtime.hasTriggeredFirstHitBonus, profile.triggers.firstHitDoubleDamage {
                    state.itemBonus += (state.amount + state.statBonus)
                    runtime.hasTriggeredFirstHitBonus = true
                    context.roster.update(runtime)
                }
            }
            if state.applyItemBonus {
                state.itemBonus += CombatTriggerEngine.damageBonus(for: state, in: &context)
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
    }

    /// Damage-dealt percent bonus from the source profile.
    private static func applyPercentBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.applyItemBonus,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword
        else { return }
        let percent = context.modifiers(for: sourceActorID).damageDealtPercent(for: damageKeyword)
        let percentBonus = CombatRounding.scaled(max(0, state.remaining), multiplier: percent)
        state.itemBonus += percentBonus
        state.remaining += percentBonus
    }

    /// Dodge-empowered talents consumed on the next attack hit: double damage
    /// (Flyby Strike / Vanish / Misdirection) and party card damage (Feint Strike).
    private static func applyDodgeEmpoweredBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: source.combatant)
        else { return }
        if runtime.pendingDamageDoubleAfterDodge {
            state.remaining *= 2
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageDoubleAfterDodge = false }
        }
        if runtime.pendingCardDamageBonus > 0 {
            state.remaining += runtime.pendingCardDamageBonus
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingCardDamageBonus = 0 }
        }
        if runtime.pendingCardDamagePercent > 0 {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.pendingCardDamagePercent
            )
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingCardDamagePercent = 0 }
        }
        if runtime.pendingDamageAfterDodge > 0 {
            state.remaining += runtime.pendingDamageAfterDodge
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageAfterDodge = 0 }
        }
        if runtime.talentDamagePercentBonus > 0, context.turnCount < runtime.talentDamagePercentUntilTurn {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.talentDamagePercentBonus
            )
        }
    }

    /// Stunned-target multiplier and Combatant Talent System target-condition multipliers.
    private static func applyStunnedAndTalentMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        if state.isAttackHit,
           let sourceActorID = state.sourceActorID,
           context.roster.hasControlStatus(for: state.combatant, keyword: .stun) {
            let multiplier = context.modifiers(for: sourceActorID).triggers.stunnedDamageMultiplier
            if multiplier > 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
            }
        }
        // Combatant Talent System target-condition multipliers (poisoned/burning/frozen/
        // bleeding/stunned/holy-vs-faction, no-Block burn, low-health poison).
        if state.applyItemBonus {
            let talentMultiplier = CombatTriggerEngine.damageMultiplier(for: state, in: context)
            if talentMultiplier != 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: talentMultiplier)
                appendAfflictedAuraLogEvents(to: &state, in: &context)
            }
        }
    }

    private static func appendAfflictedAuraLogEvents(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy
        else { return }
        let target = state.combatant
        let names = CombatTriggerEngine.partyAfflictedDamageAuras(
            targetIsPoisoned: context.roster.activeEffects(for: target).contains { $0.effect.keyword == .poison },
            targetIsBurning: context.roster.activeEffects(for: target).contains { $0.effect.keyword == .burn },
            in: context
        ).abilityNames
        for name in names {
            // `.ability` is combat-log only; chips already drop that kind.
            state.damageEvents.append(context.nextEvent(
                kind: .ability,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: 0,
                keyword: state.damageKeyword ?? .physical
            ))
        }
    }

    /// One-shot empowers consumed on the next attack hit (Revealed Flaw / Sanguine Overflow /
    /// Holy Infusion) plus the combat-long Leech-overheal bonus (Sanguine Growth).
    private static func applyOneShotEmpowers(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: source.combatant)
        else { return }
        if runtime.pendingNextHitBonus > 0 {
            state.remaining += runtime.pendingNextHitBonus
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingNextHitBonus = 0 }
        }
        if runtime.pendingAttackBonusOnFullHealth > 0 {
            state.remaining += runtime.pendingAttackBonusOnFullHealth
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingAttackBonusOnFullHealth = 0 }
        }
        if runtime.pendingNextAttackHolyBonus > 0 {
            state.remaining += runtime.pendingNextAttackHolyBonus
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingNextAttackHolyBonus = 0 }
        }
        if runtime.permanentDamageBonus > 0 {
            state.remaining += runtime.permanentDamageBonus
        }
    }

    /// Enemy-side outgoing reductions from party talents (Numbing Cold, Hamstring,
    /// Concussive Blow, Crippling Laceration, Blinding Fumes) and timed debuffs
    /// (Blinding Carapace, Dazzle).
    private static func applyEnemyOutgoingReductions(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.sourceActorID == context.roster.enemy.id else { return }
        let enemy = state.combatant
        let enemyIsFrozen = context.roster.hasControlStatus(for: enemy, keyword: .freeze)
        let enemyIsStunned = context.roster.hasControlStatus(for: enemy, keyword: .stun)
        let enemyIsPoisoned = context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .poison }
        let enemyIsBleeding = context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .bleed }
        let enemyBleedStacks = context.roster.activeEffects(for: enemy).count(where: { $0.effect.isBleed })
        var reductionFlat = 0
        var reductionMultiplier = 1.0
        for profile in [context.heroModifiers, context.companionModifiers] {
            let t = profile.triggers
            if enemyIsFrozen {
                reductionFlat += t.frozenEnemyDamageReductionFlat
            }
            if enemyIsBleeding {
                reductionFlat += t.bleedingEnemyDamageReductionFlat
            }
            if enemyIsStunned {
                reductionMultiplier *= t.stunnedEnemyNextTurnDamageMultiplier
            }
            if enemyIsPoisoned {
                reductionMultiplier *= (1 - min(1, t.poisonedEnemyAccuracyPenaltyPercent))
            }
            if enemyIsBleeding, t.enemyBleedStacksDamageReductionStacks > 0,
               enemyBleedStacks >= t.enemyBleedStacksDamageReductionStacks {
                reductionMultiplier *= (1 - min(1, t.enemyBleedStacksDamageReductionPercent))
            }
        }
        // Blinding Carapace / Dazzle timed debuffs on the enemy.
        for active in context.roster.activeEffects(for: enemy) {
            switch active.effect {
            case let .damageReductionPercent(percent, _):
                reductionMultiplier *= (1 - min(1, percent))
            case let .damageReductionFlat(amount, _):
                reductionFlat += amount
            default:
                continue
            }
        }
        state.remaining = max(0, CombatRounding.scaled(state.remaining, multiplier: reductionMultiplier) - reductionFlat)
    }

    static func applyFightPacing(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.remaining > 0 else { return }
        state.remaining = context.paced(state.remaining, sourceActorID: state.sourceActorID)
        state.dealt = state.remaining
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleState
    ) -> Int {
        let profile = context.modifiers(for: sourceActorID)
        var bonus = profile.damageDealtBonus(for: keyword)
        if sourceActorID == context.roster.companion.id {
            bonus += context.heroModifiers.companionDamageDealtBonus
            if keyword == .bleed {
                bonus += context.heroModifiers.companionBleedDamageDealtBonus
            }
        }
        if profile.triggers.damageIncreasesEveryOtherTurn {
            bonus += context.turnCount / 2
        }
        return bonus
    }

    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in _: inout BattleState
    ) {
        guard state.sourceActorID != nil else { return }
        let effects = state.activeEffects
        guard effects.contains(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }) else {
            return
        }

        guard let index = effects.firstIndex(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }),
            case let .marked(bonus, _) = effects[index].effect
        else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.markedBonusApplied = true
    }

    static func applyItemReduction(
        to state: inout DamageResolutionState,
        in context: inout BattleState
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
        let flatReduction = profile.damageTakenFlat(for: damageKeyword)
        if flatReduction > 0 {
            state.remaining = max(0, state.remaining - flatReduction)
        }
        let reduction = min(1, profile.damageTakenReduction(for: damageKeyword))
        if reduction > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - reduction)
        }
        let vulnerability = profile.damageTakenVulnerability(for: damageKeyword)
        if vulnerability > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + vulnerability)
        }
        // Talent damage-type resistances (Tough Pelt / Steadfast / Lichbone).
        let defenderTriggers = profile.triggers
        var talentResistance = 0.0
        if damageKeyword == .bleed {
            talentResistance = max(talentResistance, defenderTriggers.bleedResistance, defenderTriggers.afflictionResistance)
        }
        if damageKeyword == .poison {
            talentResistance = max(talentResistance, defenderTriggers.afflictionResistance)
        }
        if damageKeyword == .burn,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0 {
            talentResistance = max(talentResistance, defenderTriggers.blockedControlBurnResistance)
        }
        if talentResistance > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 - min(1, talentResistance))
        }
        state.buildupDamage = state.remaining
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.isCritical, state.remaining > 0 else {
            state.buildupDamage = state.remaining
            return
        }
        var critMultiplier = 2.0
        // Stalker's Precision: each Dodge raises this combatant's crit multiplier.
        if let sourceActorID = state.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            critMultiplier += context.roster.runtime(for: source.combatant)?.talentCritMultiplierBonus ?? 0
        }
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: critMultiplier)
        state.dealt = state.remaining
        state.buildupDamage = state.remaining
    }

    /// Toughness-based inherent DR: percentage reduction from Toughness (K = 80)
    /// plus flat passive mitigation from traits/affixes.
    static func applyMitigation( // swiftlint:disable:this function_body_length
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.remaining > 0 else { return }

        let effects = context.roster.activeEffects(for: state.combatant)
        let profile = context.modifiers(for: state.combatant.id)
        let defenderTriggers = profile.triggers
        var effectivePercent = DefensePoolEngine.effectiveToughnessMitigationPercent(
            for: state.combatant,
            effects: effects,
            profile: profile,
            in: context
        )
        if let sourceActorID = state.sourceActorID {
            let ignorePercent = min(1, context.modifiers(for: sourceActorID).triggers.ignoreEnemyMitigationPercent)
            if ignorePercent > 0 {
                effectivePercent *= (1 - ignorePercent)
            }
            if state.damageKeyword == .leech,
               context.modifiers(for: sourceActorID).triggers.leechIgnoresMitigation {
                effectivePercent = 0
            }
            // Searing Heat / Molten Heat: Burn damage ignores all enemy mitigation.
            if state.damageKeyword == .burn,
               context.modifiers(for: sourceActorID).triggers.burnIgnoresBlockAndMitigation {
                effectivePercent = 0
            }
            // Deep Wounds: Bleed ignores enemy armor and damage reduction.
            if state.damageKeyword == .bleed,
               context.modifiers(for: sourceActorID).triggers.bleedsIgnoreMitigation {
                effectivePercent = 0
            }
        }

        var remaining = state.remaining
        if defenderTriggers.passiveMitigationFlat > 0 {
            remaining = max(0, remaining - defenderTriggers.passiveMitigationFlat)
        }

        // Hardened Chitin: take less damage from spells (non-Physical keywords)
        // while holding Block.
        if state.damageKeyword != .physical,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant)) > 0,
           defenderTriggers.spellDamageTakenReductionWhileBlocked > 0 {
            remaining = max(0, remaining - defenderTriggers.spellDamageTakenReductionWhileBlocked)
        }

        // Bulwark Fortress: while the Companion holds Block, the Hero takes less damage.
        if state.combatant.role == .hero,
           context.roster.companion.isAlive,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: context.roster.companion.combatant)) > 0 {
            let protection = min(1, max(0, context.companionModifiers.triggers.companionBlockProtectsHeroPercent))
            if protection > 0 {
                remaining = CombatRounding.scaled(remaining, multiplier: 1 - protection)
            }
        }
        // Guardian: the Companion absorbs damage whenever the Hero is attacked.
        if state.combatant.role == .hero,
           context.roster.companion.isAlive,
           context.companionModifiers.triggers.absorbHeroDamageFlat > 0 {
            remaining = max(0, remaining - context.companionModifiers.triggers.absorbHeroDamageFlat)
        }
        // Aetherial Armor: 1 damage reduction per 2 unspent Mana.
        if defenderTriggers.damageReductionPerUnspentManaEvery > 0,
           let runtime = context.roster.runtime(for: state.combatant),
           runtime.maxMana > 0,
           runtime.currentMana > 0 {
            remaining = max(0, remaining - runtime.currentMana / defenderTriggers.damageReductionPerUnspentManaEvery)
        }

        if effectivePercent > 0 {
            remaining = CombatRounding.scaled(remaining, multiplier: 1.0 - effectivePercent)
        }

        state.remaining = remaining
        state.buildupDamage = state.remaining
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        guard state.markedBonusApplied else { return }

        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: {
            if case .marked = $0.effect {
                return true
            }; return false
        }),
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

    static func applyDeathsDoor(
        to state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        state.damageEvents.append(contentsOf: DeathsDoorEngine.resolveAfterDamage(
            to: state.combatant,
            in: &context
        ))
    }
}
