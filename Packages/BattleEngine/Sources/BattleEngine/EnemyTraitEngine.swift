import Foundation
import TrinketContent
import TrinketCore

package enum EnemyTraitEngine {
    static func applyOutgoingAttackTraits(from state: CommittedDamage, context: inout BattleState) async {
        guard state.sourceActorID == context.enemy.id,
              state.combatant.role != .enemy,
              context.health(of: state.combatant) > 0,
              context.roster.enemy.isAlive
        else { return }
        await basicBurn(from: state, context: &context)
        await basicFreezeDamage(from: state, context: &context)
        guard state.options.isPrimaryAttack,
              context.health(of: state.combatant) > 0,
              context.roster.enemy.isAlive
        else { return }
        await firstAttackBleedBonus(from: state, context: &context)
        guard context.health(of: state.combatant) > 0,
              context.roster.enemy.isAlive
        else { return }
        let triggers = context.enemyModifiers.triggers
        if triggers.attacksApplyBleed > 0 {
            await DoTApplicator.applyBleed(
                potency: triggers.attacksApplyBleed, to: state.combatant,
                sourceActorID: context.enemy.id, application: .afterHit, in: &context,
            )
        }
        if triggers.attacksApplyPoison > 0 {
            await context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.attacksApplyPoison,
                to: state.combatant,
                sourceActorID: context.enemy.id,
                application: .reaction,
            )
        }
    }

    private static func firstAttackBleedBonus(from state: CommittedDamage, context: inout BattleState) async {
        let source = context.roster.enemy
        let modifiers = context.enemyModifiers
        let triggers = modifiers.triggers
        guard triggers.firstAttackBleedBonus > 0,
              !source.hasTriggeredFirstAttackBleedBonus
        else { return }
        context.roster.enemy.hasTriggeredFirstAttackBleedBonus = true

        let amount = triggers.firstAttackBleedBonus
        let outcome = await context.dealReactionDamage(amount, to: state.combatant, keyword: .bleed, sourceActorID: source.id)

        if outcome.healthLost > 0 {
            context.nextEvent(
                kind: .status, source: .init(source),
                abilityName: modifiers.triggerAbilityName(
                    .firstAttackBleedBonus, fallback: "Hidden Fangs",
                ),
                target: state.combatant, amount: outcome.healthLost, keyword: .bleed,
            )
        }
        await DoTApplicator.applyBleed(
            potency: amount,
            to: state.combatant,
            sourceActorID: source.id,
            application: .afterHit,
            in: &context,
        )
    }

    private static func basicFreezeDamage(from state: CommittedDamage, context: inout BattleState) async {
        let amount = context.enemyModifiers.triggers.basicAttackFreezeBuildup
        let immediateBasic = state.provenance != nil
            && state.provenance == context.resolution.damageProvenance(for: context.enemy.id)
            && context.resolution.actionOutcome?.ability.tier == .basic
        guard amount > 0, state.options.isBasicAttackHit || immediateBasic else { return }
        if let actionID = context.resolution.actionID {
            guard context.resolution.claim(
                .heroTalent(.basicAttackFreezeBuildup), actorID: context.enemy.id, cadence: .action(actionID),
            ) else { return }
        }
        _ = await context.dealReactionDamage(amount, to: state.combatant, keyword: .freeze, sourceActorID: context.enemy.id)
    }

    package static func turnFreeze(
        for combatant: Combatant,
        context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: combatant.id)
        let interval = profile.triggers.turnFreezeDamageAllEnemiesInterval
        guard profile.triggers.turnFreezeDamageAllEnemies > 0,
              context.roster.health(for: combatant) > 0,
              context.turnCount > 0,
              interval > 0,
              context.turnCount.isMultiple(of: interval)
        else { return }

        await turnDamageAllEnemies(
            amount: profile.triggers.turnFreezeDamageAllEnemies,
            keyword: .freeze,
            abilityName: profile.triggerAbilityName(.turnFreezeDamageAllEnemies, fallback: "Trait"),
            source: combatant,
            context: &context,
        )
    }

    package static func turnRandomDamageAllEnemies(
        for combatant: Combatant,
        context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: combatant.id)
        let triggers = profile.triggers
        let interval = triggers.turnRandomDamageAllEnemiesInterval
        guard triggers.turnRandomDamageAllEnemiesAmount > 0,
              let first = triggers.turnRandomDamageAllEnemiesKeywordA,
              let second = triggers.turnRandomDamageAllEnemiesKeywordB,
              context.roster.health(for: combatant) > 0,
              context.turnCount > 0,
              interval > 0,
              context.turnCount.isMultiple(of: interval)
        else { return }

        let chosen = BattleChance.succeeds(probability: 0.5, using: &context.rng) ? first : second
        await turnDamageAllEnemies(
            amount: triggers.turnRandomDamageAllEnemiesAmount,
            keyword: chosen,
            abilityName: profile.triggerAbilityName(.turnRandomDamageAllEnemiesAmount, fallback: "Trait"),
            source: combatant,
            context: &context,
        )
    }

    private static func turnDamageAllEnemies(
        amount: Int,
        keyword: Keyword,
        abilityName: String,
        source: Combatant,
        context: inout BattleState,
    ) async {
        let action = BattleActionContext(actor: source, in: context)
        for target in action.opponents(in: context) {
            guard !context.isBattleOver, action.canContinue(in: context) else { break }
            guard context.health(of: target) > 0 else { continue }
            let outcome = await context.dealReactionDamage(amount, to: target, keyword: keyword, sourceActorID: source.id)
            if outcome.healthLost > 0 {
                context.nextEvent(
                    kind: .abilityDamage, source: .init(source), abilityName: abilityName,
                    target: target, amount: outcome.healthLost, keyword: keyword, isCritical: outcome.isCritical,
                )
            }
            let stackPotency = keyword == .bleed ? amount : outcome.healthLost
            await DoTApplicator.applyDoT(
                keyword: keyword,
                potency: stackPotency,
                to: target,
                sourceActorID: source.id,
                application: .attached,
                in: &context,
            )
        }
    }

    package static func traitAttackerBurn(
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: defender.id)
        guard profile.triggers.onHitAttackerBurn > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return }

        await DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: profile.triggers.onHitAttackerBurn,
            to: attacker,
            sourceActorID: defender.id,
            application: .attached,
            in: &context,
        )
    }

    package static func traitThornsDamage(
        damageTaken: Int,
        defender: Combatant,
        attackerID: String,
        in context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: defender.id)
        guard profile.triggers.thornsPercent > 0, damageTaken > 0,
              let attacker = context.roster.combatant(for: attackerID)?.combatant
        else { return }

        let thornsAmount = CombatRounding.scaled(damageTaken, multiplier: profile.triggers.thornsPercent)
        guard thornsAmount > 0 else { return }
        var operation = DamageOperation.reaction()
        operation.isThornsDamage = true
        let outcome = await context.resolveDamage(
            DamageRequest(
                amount: thornsAmount,
                target: attacker,
                keyword: .physical,
                sourceActorID: defender.id,
                options: operation,
            ),
        )

        if outcome.healthLost > 0 {
            context.nextEvent(
                kind: .effect(.thornsTriggered),
                source: .init(defender),
                abilityName: profile.triggerAbilityName(.thornsPercent, fallback: "Trait"),
                target: attacker,
                amount: outcome.healthLost,
                keyword: .physical,
            )
        }
        await DamagePipeline.thornsRewards(healthLost: outcome.healthLost, attacker: attacker, defender: defender, in: &context)
    }
}
