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
        let empoweredKeyword = ability.damageComponents.first(where: \.isManaEmpowerableBurnOrFreezeDamage)?.keyword
        let repeats = ability.repeatsManaEmpowerment
            || (ability.hasManaEmpowerableBurnDamage
                && context.modifiers(for: actor.id).triggers.repeatManaEmpowerment)
        let triggers = context.modifiers(for: actor.id).triggers
        let isHealingCard = ability.keywords.contains(.health)
        let baseCost: Int = if isHealingCard, triggers.healingEmpowermentCostReduction > 0 {
            max(0, manaEmpowermentCost - triggers.healingEmpowermentCostReduction)
        } else if triggers.empowermentCostReduction > 0 {
            max(0, manaEmpowermentCost - triggers.empowermentCostReduction)
        } else {
            manaEmpowermentCost
        }
        var events: [ActionEvent] = []
        var purchases = 0
        var totalManaSpent = 0
        let patron = empowermentPatron(for: ability, actor: actor, in: context)
        let maxMana = (context.roster.runtime(for: actor)?.maxMana ?? 0) + (patron?.maxMana ?? 0)
        let firstDiscount = context.roster.runtime(for: actor)?.hasEmpoweredWithMana == false
            && triggers.firstEmpowermentCostReduction > 0 ? 1 : 0
        let maxPurchases = baseCost == 0 ? 1 : max(1, maxMana / baseCost + firstDiscount)
        while purchases == 0 || repeats, purchases < maxPurchases {
            guard let runtime = context.roster.runtime(for: actor), maxMana > 0 else { break }
            let discount = runtime.hasEmpoweredWithMana ? 0 : triggers.firstEmpowermentCostReduction
            let empowermentCost = max(0, baseCost - discount)
            guard let payment = payEmpowerment(
                empowermentCost,
                ability: ability,
                actor: actor,
                in: &context,
            ) else { break }
            context.roster.mutateRuntime(for: actor) { $0.hasEmpoweredWithMana = true }
            purchases += 1
            totalManaSpent += payment.reduce(0) { $0 + $1.amount }
            ability = ability.empoweredByMana(
                amount: manaEmpowermentBonus + triggers.empowermentDamageBonus,
                includingBothElements: triggers.prismaticScales,
            )
            for contribution in payment where contribution.amount > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterSpendMana(
                    by: contribution.actor, amountSpent: contribution.amount, in: &context,
                ))
            }
        }
        if purchases > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterHeroTalentSpendMana(actor: actor, amount: 0, empowered: true, in: &context))
        }
        if totalManaSpent > 0, let empoweredKeyword {
            events.append(contentsOf: CombatTriggerEngine.drawOppositeElement(
                afterEmpowering: empoweredKeyword,
                by: actor,
                in: &context,
            ))
        }
        return events
    }
}

private extension BattleTurnEngine {
    struct ManaContribution {
        let actor: Combatant
        let amount: Int
    }

    static func empowermentPatron(for ability: Ability, actor: Combatant, in context: BattleState) -> CombatantRuntime? {
        guard actor.role != .enemy, ability.keywords.contains(.freeze) else { return nil }
        return [BattleParticipant.hero, .companion].map { context.roster[$0] }.first {
            $0.id != actor.id && $0.isAlive && context.modifiers(for: $0.id).triggers.dragonPatronage
        }
    }

    static func payEmpowerment(
        _ cost: Int,
        ability: Ability,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ManaContribution]? {
        guard let runtime = context.roster.runtime(for: actor) else { return nil }
        let ownMana = min(cost, runtime.currentMana)
        let patron = empowermentPatron(for: ability, actor: actor, in: context)
        let sharedMana = min(cost - ownMana, patron?.currentMana ?? 0)
        let shortfall = cost - ownMana - sharedMana
        let rate = ability.keywords.contains(.freeze) ? context.modifiers(for: actor.id).triggers.freezeEmpowermentBlockPerMana : 0
        guard shortfall == 0 || rate > 0 else { return nil }
        let blockCost = shortfall * rate
        let block = DefensePoolEngine.blockPoints(in: runtime.activeEffects)
        guard block >= blockCost else { return nil }
        if blockCost > 0 {
            DefensePoolEngine.set(block - blockCost, on: actor, in: &context)
        }
        let spent = context.spendMana(ownMana, for: actor)
        UniqueCombatEngine.afterEmpowermentSpend(spent, previousMana: runtime.currentMana, actor: actor, in: &context)
        var payment = [ManaContribution(actor: actor, amount: spent)]
        if let patron, sharedMana > 0 {
            let shared = context.spendMana(sharedMana, for: patron.combatant)
            payment.append(ManaContribution(actor: patron.combatant, amount: shared))
        }
        return payment
    }
}
