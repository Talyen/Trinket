import TrinketContent
import TrinketCore

public extension BattleTurnEngine {
    static let manaEmpowermentCost = 3
    static let manaEmpowermentBonus = 1

    @discardableResult
    static func spendManaToEmpowerBurnOrFreezeIfNeeded(
        for ability: inout Ability,
        actor: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage else { return [] }
        let empoweredKeyword = ability.operations.first(where: \.isManaEmpowerable)?.keyword
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        var purchases = 0
        var totalManaSpent = 0
        let purchaseLimit = ManaEmpowermentBudget(ability: ability, actor: actor, in: context).purchaseLimit
        while purchases < purchaseLimit {
            guard let payment = payEmpowerment(ability: ability, actor: actor, in: &context) else { break }
            context.roster.mutateRuntime(for: actor) { $0.hasEmpoweredWithMana = true }
            purchases += 1
            totalManaSpent += payment.reduce(0) { $0 + $1.amount }
            ability = empoweredAbility(ability, triggers: triggers)
            for contribution in payment where contribution.amount > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterSpendMana(
                    by: contribution.actor, amountSpent: contribution.amount, in: &context,
                ))
            }
        }
        if purchases > 0 {
            context.roster.mutateRuntime(for: actor) { $0.empoweredThisAction = true }
            events.append(contentsOf: CombatTriggerEngine.afterHeroTalentSpendMana(actor: actor, amount: 0, empowered: true, in: &context))
        }
        if totalManaSpent > 0, let empoweredKeyword {
            events.append(contentsOf: CombatTriggerEngine.drawOppositeElement(
                afterEmpowering: empoweredKeyword,
                by: actor,
                in: &context,
            ))
        }
        if totalManaSpent > 0, empoweredKeyword == .burn, triggers.onEmpowerBurnRestoreMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.onEmpowerBurnRestoreMana,
                to: actor,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    "onEmpowerBurnRestoreMana",
                    for: actor,
                    fallback: "Pyromancer's Spark",
                    in: context,
                ),
            ))
        }
        return events
    }
}

private extension BattleTurnEngine {
    static func empoweredAbility(_ original: Ability, triggers: CombatTraitTriggers) -> Ability {
        let ability = original.empoweredByMana(
            amount: manaEmpowermentBonus + triggers.empowermentDamageBonus,
            includingBothElements: triggers.prismaticScales,
        )
        guard triggers.flashFreeze || triggers.empowerFreezeDamageBonus > 0 else { return ability }
        let freezeBonus = (triggers.flashFreeze ? 2 : 0) + triggers.empowerFreezeDamageBonus
        var operations = ability.operations.map {
            $0.keyword == .freeze ? $0.empowered(by: freezeBonus) : $0
        }
        if !operations.contains(where: { $0.keyword == .freeze }), triggers.empowerFreezeDamageBonus > 0,
           let first = ability.operations.first(where: \.isManaEmpowerable) {
            operations.append(.damage(DamageComponent(
                freezeBonus, keyword: .freeze, target: first.target, condition: first.condition,
            )))
        }
        return ability.replacingOperations(operations)
    }

    struct ManaContribution {
        let actor: Combatant
        let amount: Int
    }

    static func payEmpowerment(
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ManaContribution]? {
        guard let runtime = context.roster.runtime(for: actor) else { return nil }
        var budget = ManaEmpowermentBudget(ability: ability, actor: actor, in: context)
        guard let quote = budget.nextPayment() else { return nil }
        let blockCost = quote.block
        let block = DefensePoolEngine.blockPoints(in: runtime.activeEffects)
        guard block >= blockCost else { return nil }
        if blockCost > 0 {
            DefensePoolEngine.set(block - blockCost, on: actor, in: &context)
        }
        let spent = context.spendMana(quote.ownMana, for: actor)
        UniqueCombatEngine.afterEmpowermentSpend(spent, previousMana: runtime.currentMana, actor: actor, in: &context)
        var payment = [ManaContribution(actor: actor, amount: spent)]
        if let partner = budget.partner, quote.partnerMana > 0 {
            let shared = context.spendMana(quote.partnerMana, for: partner)
            payment.append(ManaContribution(actor: partner, amount: shared))
        }
        return payment
    }
}
