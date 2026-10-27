import TrinketContent
import TrinketCore

/// Affixes that strengthen an existing result without emitting another combat event.
enum QuietAffixRules {
    static func prepareAttack(ability: Ability, actor: Combatant, in context: inout BattleState) -> Int {
        guard actor.role != .enemy, context.modifiers(for: actor.id).triggers.alternatingAttackDamageBonus > 0,
              let facts = context.resolution.actionOutcome,
              let component = ability.operations.lazy.compactMap(\.damageComponent).first(where: {
                  $0.target != .actor && $0.hasPotentialDamage
                      && BattleDamageRules.isEnabled($0, action: facts.action, in: context)
              }) else { return 0 }
        return prepareAttackType(component.keyword, actor: actor, in: &context)
    }

    private static func prepareAttackType(_ keyword: Keyword, actor: Combatant, in context: inout BattleState) -> Int {
        let amount = context.modifiers(for: actor.id).triggers.alternatingAttackDamageBonus
        guard amount > 0 else { return 0 }
        let previous = context.roster.runtime(for: actor)?.talents.history.previousAttackKeyword
        context.roster.mutateRuntime(for: actor) { $0.talents.history.previousAttackKeyword = keyword }
        guard let previous, previous != keyword else { return 0 }
        return amount
    }

    static func afterAttackCard(_ facts: ResolvedActionFacts, in context: inout BattleState) {
        let actor = facts.action.actor
        guard !facts.damageKeywords.isEmpty,
              let owner = context.roster.participant(for: actor), owner.isPartyMember,
              context.roster[owner].isAlive else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        let partner: BattleParticipant = owner == .hero ? .companion : .hero
        context.prepareAttackBonus(triggers.attackPreparesAllyDamage, \.nextRelayAttackBonus, for: context.roster[partner].combatant)
        context.prepareAttackBonus(triggers.attackPreparesBlockBonus, \.nextAttackBlockBonus, for: actor)
    }

    static func applyAttackBonuses(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, state.options.applyItemBonus, state.amount > 0,
              state.combatant.role == .enemy,
              let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID), source.role != .enemy else { return }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceID).triggers
        let sourceEffects = context.roster.activeEffects(for: actor)
        var bonus = context.consumeTalentPreparation(\.nextRelayAttackBonus, for: actor) ?? 0
        let prismatic: Int = if let action = context.resolution.actionTalents(for: sourceID) {
            action.prismaticAffixDamageBonus
        } else if let keyword = state.damageKeyword {
            prepareAttackType(keyword, actor: actor, in: &context)
        } else {
            0
        }
        bonus = SaturatedArithmetic.saturatingAdd(bonus, prismatic)
        if triggers.attackDamageVsHigherBlockBonus != 0,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: state.combatant))
           > DefensePoolEngine.blockPoints(in: sourceEffects) {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.attackDamageVsHigherBlockBonus)
        }
        if state.targetStatus.isBurning, state.targetStatus.isPoisoned {
            bonus = SaturatedArithmetic.saturatingAdd(bonus, triggers.attackDamageVsBurningPoisonedBonus)
        }
        if triggers.attackDamagePerEnemyBuff > 0 {
            let buffs = Set(context.roster.activeEffects(for: state.combatant).lazy
                .filter(\.effect.isRemovableBuff).map(\.effect.kind)).count
            bonus = SaturatedArithmetic.saturatingAdd(bonus, SaturatedArithmetic.saturatingMul(buffs, triggers.attackDamagePerEnemyBuff))
        }
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
        if triggers.attackDamageWithoutDebuffsPercent > 0,
           !sourceEffects.contains(where: \.effect.isRemovableDebuff) {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + triggers.attackDamageWithoutDebuffsPercent)
        }
    }

    static func applyBlockOverflow(to state: inout DamageResolutionState, in context: BattleState) {
        guard state.options.isAttackHit,
              state.heroCardBlockBroken, state.remaining > 0, state.combatant.role == .enemy,
              let sourceID = state.sourceActorID else { return }
        let percent = context.modifiers(for: sourceID).triggers.attackBlockBreakOverflowPercent
        guard percent > 0 else { return }
        state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + percent)
    }

    static func healingBonus(sourceID: String?, in context: BattleState) -> Int {
        guard let sourceID, let source = context.roster.combatant(for: sourceID), source.role != .enemy,
              context.roster.hasControlStatus(for: context.enemy, keyword: .stun)
              || context.roster.hasControlStatus(for: context.enemy, keyword: .freeze) else { return 0 }
        return context.modifiers(for: sourceID).triggers.healingWhileEnemyControlledBonus
    }

    static func blockGainMultiplier(for target: Combatant, in context: BattleState) -> Double {
        guard let owner = context.roster.participant(for: target), owner.isPartyMember else { return 1 }
        let partner: BattleParticipant = owner == .hero ? .companion : .hero
        guard context.roster[partner].isAlive,
              DefensePoolEngine.blockPoints(in: context.roster[partner].activeEffects) > 0 else { return 1 }
        return 1 + context.modifiers(for: target.id).triggers.blockGainWhileAllyBlockedPercent
    }
}
