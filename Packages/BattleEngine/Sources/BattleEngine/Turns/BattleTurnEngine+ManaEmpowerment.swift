import TrinketContent
import TrinketCore

package extension BattleTurnEngine {
    static let manaEmpowermentCost = 3
    static let manaEmpowermentBonus = 1

    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleState,
    ) async {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return }
        let empoweredKeyword = ability.operations.first(where: \.isManaEmpowerable)?.keyword
        let triggers = context.modifiers(for: actor.id).triggers

        var purchases = 0
        var spentMana = false
        let purchaseLimit = ManaEmpowermentBudget(ability: ability, actor: actor, in: context).purchaseLimit
        while purchases < purchaseLimit, !context.isBattleOver, context.roster.health(for: actor) > 0 {
            guard let payment = payEmpowerment(ability: ability, actor: actor, in: &context) else { break }
            context.roster.mutateRuntime(for: actor) {
                $0.talents.battle.hasEmpoweredWithMana = true
                $0.talents.pending.nextManaEmpowerDiscount = 0
            }
            purchases += 1
            spentMana = spentMana || payment.contains { $0.amountSpent > 0 }
            ability = empoweredAbility(ability, triggers: triggers)
            await CombatTriggerEngine.afterHeroTalentSpendMana(actor: actor, amount: 0, empowered: true, in: &context)
            for contribution in payment where contribution.amountSpent > 0 {
                guard CombatCheckpoint.preparedAction(actor.id).allowsContinuation(in: context) else { break }
                await CombatTriggerEngine.afterSpendMana(contribution, in: &context)
            }
        }
        guard context.roster.health(for: actor) > 0 else { return }
        if purchases > 0 {
            markEmpoweredAction(actor: actor, triggers: triggers, in: &context)
            grantDragonPatronageBlock(actor: actor, amount: triggers.manaEmpowerAllyBlock, in: &context)
            if triggers.manaEmpowerNextAttackPercent > 0 {
                context.prepareTalentBonus(triggers.manaEmpowerNextAttackPercent, \.overchargePercent, for: actor, merging: max)
            }
            if BattleChance.succeeds(
                probability: triggers.manaEmpoweredAttackDoubleChancePercent,
                using: &context.rng,
            ) {
                ability = doubledDamageAbility(ability)
            }
        }
        if spentMana, let empoweredKeyword {
            CombatTriggerEngine.drawOppositeElement(afterEmpowering: empoweredKeyword, by: actor, in: &context)
        }
        if spentMana, empoweredKeyword == .burn, triggers.onEmpowerBurnRestoreMana > 0 {
            await context.restoreManaEmitting(
                triggers.onEmpowerBurnRestoreMana,
                to: actor,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .onEmpowerBurnRestoreMana,
                    for: actor,
                    fallback: "Pyromancer's Spark",
                    in: context,
                ),
            )
        }
    }
}

private extension BattleTurnEngine {
    static func markEmpoweredAction(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let arcaneBurst = triggers.manaEmpowerDamageMultiplier > 1
            && BattleChance.succeeds(probability: triggers.manaEmpowerDamageChancePercent, using: &context.rng)
        context.resolution.recordManaEmpowerment(by: actor.id, arcaneBurst: arcaneBurst)
    }

    static func grantDragonPatronageBlock(actor: Combatant, amount: Int, in context: inout BattleState) {
        guard amount > 0, actor.role == .companion, context.roster.hero.isAlive else { return }
        context.applyBlockGain(amount, to: context.roster.hero.combatant, source: actor, abilityName: "Dragon’s Patronage")
    }

    static func empoweredAbility(_ original: Ability, triggers: CombatTraitTriggers) -> Ability {
        let ability = original.empoweredByMana(
            amount: SaturatedArithmetic.saturatingAdd(manaEmpowermentBonus, triggers.empowermentDamageBonus),
            includingBothElements: triggers.prismaticScales,
        )
        guard triggers.flashFreeze || triggers.empowerFreezeDamageBonus > 0
            || triggers.empowerBurnDamageBonus > 0 else { return ability }
        let freezeBonus = SaturatedArithmetic.saturatingAdd(triggers.flashFreeze ? 2 : 0, triggers.empowerFreezeDamageBonus)
        let operations = ability.operations.map {
            if $0.keyword == .freeze, freezeBonus > 0 {
                return $0.empowered(by: freezeBonus)
            }
            if $0.keyword == .burn, triggers.empowerBurnDamageBonus > 0 {
                return $0.empowered(by: triggers.empowerBurnDamageBonus)
            }
            return $0
        }
        return ability.replacingOperations(operations)
    }

    static func doubledDamageAbility(_ ability: Ability) -> Ability {
        let operations = ability.operations.map { operation -> AbilityOperation in
            switch operation {
            case let .damage(component):
                guard component.target != .actor else { return operation }
                return .damage(DamageComponent(
                    SaturatedArithmetic.saturatingMul(component.amount, 2),
                    keyword: component.keyword,
                    target: component.target,
                    bonusAmount: SaturatedArithmetic.saturatingMul(component.bonusAmount, 2),
                    condition: component.condition,
                    scaling: component.scaling, hasLeech: component.hasLeech,
                ))
            case let .effect(targeted):
                guard case let .recurringDamage(keyword, amount, turns) = targeted.effect else { return operation }
                return .effect(TargetedEffect(
                    .recurringDamage(keyword, SaturatedArithmetic.saturatingMul(amount, 2), turns),
                    target: targeted.target,
                    condition: targeted.condition, chance: targeted.chance,
                ))
            }
        }
        return ability.replacingOperations(operations)
    }

    static func payEmpowerment(
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ManaPayment]? {
        guard let runtime = context.roster.runtime(for: actor) else { return nil }
        var budget = ManaEmpowermentBudget(ability: ability, actor: actor, in: context)
        guard let quote = budget.nextPayment() else { return nil }
        let blockCost = quote.block
        let block = DefensePoolEngine.blockPoints(in: runtime.activeEffects)
        guard block >= blockCost else { return nil }
        if blockCost > 0 {
            DefensePoolEngine.set(block - blockCost, on: actor, in: &context)
        }
        let spent = context.payMana(quote.ownMana, for: actor)
        var payment = [spent]
        if let partner = budget.partner, quote.partnerMana > 0 {
            payment.append(context.payMana(quote.partnerMana, for: partner))
        }
        UniqueCombatEngine.afterEmpowermentSpend(spent, in: &context)
        return payment
    }
}
