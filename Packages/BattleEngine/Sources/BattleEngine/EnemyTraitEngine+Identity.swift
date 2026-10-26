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
        prepareAttack(for: actor, context: &context)
        return true
    }

    static func attackBurn(from state: CommittedDamage, context: inout BattleState) async {
        let amount = context.enemyModifiers.triggers.basicAttackApplyBurn
        guard amount > 0 else { return }
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
        guard amount > 0, state.damageKeyword == .poison, state.amount > 0,
              state.combatant.role != .enemy, !context.isBattleOver, context.roster.enemy.isAlive
        else { return }
        await CombatTriggerEngine.emitHeal(
            .healOnOpponentPoisonDamage, "Plague Mask", amount: amount, to: actor, source: actor, in: &context,
        )
    }
}

extension EnemyTraitEngine {
    static func beforeHit(_ state: DamageResolutionState, context: inout BattleState) {
        guard state.options.isPrimaryAttack, state.amount > 0,
              state.sourceActorID == context.enemy.id, state.combatant.role != .enemy,
              !context.isBattleOver else { return }
        let profile = context.enemyModifiers
        DefensePoolEngine.steal(
            profile.triggers.attackStealBlock, from: state.combatant, to: context.enemy,
            abilityName: profile.triggerAbilityName(.attackStealBlock, fallback: "Pilfer"), in: &context,
        )
    }

    static func afterHit(_ state: CommittedDamage, landed: Bool, context: inout BattleState) async {
        guard state.options.isPrimaryAttack, state.amount > 0,
              state.sourceActorID == context.enemy.id, state.combatant.role != .enemy,
              !context.isBattleOver, context.roster.enemy.isAlive else { return }
        await afterEnemyHit(landed: landed, context: &context)
    }

    static func afterEnemyHit(landed: Bool, context: inout BattleState) async {
        guard !context.isBattleOver, context.roster.enemy.isAlive else { return }
        let actor = context.enemy
        let profile = context.enemyModifiers
        if landed, profile.triggers.attackHealFlat > 0 {
            await CombatTriggerEngine.emitHeal(
                .attackHealFlat, "Siphon", amount: profile.triggers.attackHealFlat,
                to: actor, source: actor, in: &context,
            )
        }
        guard !context.isBattleOver, profile.triggers.attackHealthRecoil > 0 else { return }
        let outcome = await context.resolveDamage(DamageRequest(
            amount: profile.triggers.attackHealthRecoil, target: actor, sourceActorID: actor.id, options: .healthCost,
        ))
        context.nextEvent(
            kind: .abilityDamage, source: .init(actor),
            abilityName: profile.triggerAbilityName(.attackHealthRecoil, fallback: "Self-Sacrifice"),
            target: actor, amount: outcome.healthLost, keyword: .health,
        )
    }
}
