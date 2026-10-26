import TrinketContent
import TrinketCore

extension EnemyTraitEngine {
    static func beforeAttack(_ facts: ResolvedActionFacts, context: inout BattleState) async -> Bool {
        let actor = facts.action.actor
        guard actor.role == .enemy, !facts.damageKeywords.isEmpty else { return true }
        guard !context.isBattleOver, facts.action.canContinue(in: context) else { return false }
        let profile = context.enemyModifiers
        let cost = profile.triggers.attackHealthCost
        if cost > 0 {
            guard BattleAbilityRules.canPayHealthCost(facts.ability, action: facts.action, in: context) else { return false }
            let outcome = await context.resolveDamage(DamageRequest(
                amount: cost, target: actor, sourceActorID: actor.id, options: .healthCost,
            ))
            context.nextEvent(
                kind: .abilityDamage, source: .init(actor),
                abilityName: profile.triggerAbilityName(.attackHealthCost, fallback: "Blood Offering"),
                target: actor, amount: outcome.healthLost, keyword: .health,
            )
        }
        guard !context.isBattleOver, facts.action.canContinue(in: context) else { return false }
        DefensePoolEngine.steal(
            profile.triggers.attackStealBlock, from: facts.action.selectedTarget, to: actor,
            abilityName: profile.triggerAbilityName(.attackStealBlock, fallback: "Pilfer"), in: &context,
        )
        return true
    }

    static func basicBurn(from state: CommittedDamage, context: inout BattleState) async {
        let amount = context.enemyModifiers.triggers.basicAttackApplyBurn
        let immediateBasic = state.provenance != nil
            && state.provenance == context.resolution.damageProvenance(for: context.enemy.id)
            && context.resolution.actionOutcome?.ability.tier == .basic
        guard amount > 0, state.options.isBasicAttackHit || immediateBasic else { return }
        if let actionID = context.resolution.actionID {
            guard context.resolution.claim(
                .heroTalent(.basicAttackApplyBurn), actorID: context.enemy.id, cadence: .action(actionID),
            ) else { return }
        }
        await DoTApplicator.applyDecayingDoT(
            keyword: .burn, potency: amount, to: state.combatant,
            sourceActorID: context.enemy.id, application: .afterHit, in: &context,
        )
    }

    static func turnHealth(context: inout BattleState) async {
        let actor = context.enemy
        let amount = context.enemyModifiers.triggers.healthAtTurnStart
        guard amount > 0, !context.isBattleOver, context.roster.enemy.isAlive else { return }
        await CombatTriggerEngine.emitHeal(
            .healthAtTurnStart, "Reform", amount: amount, to: actor, source: actor, in: &context,
        )
    }

    static func poisonHealing(from state: CommittedDamage, context: inout BattleState) async {
        let actor = context.enemy
        let amount = context.enemyModifiers.triggers.healOnOpponentPoisonDamage
        guard amount > 0, state.damageKeyword == .poison, state.healthLost > 0,
              state.combatant.role != .enemy, !context.isBattleOver, context.roster.enemy.isAlive
        else { return }
        await CombatTriggerEngine.emitHeal(
            .healOnOpponentPoisonDamage, "Plague Mask", amount: amount, to: actor, source: actor, in: &context,
        )
    }
}
