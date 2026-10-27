import TrinketContent
import TrinketCore

extension BattleState {
    func assessmentResources(
        _ branch: AbilityOutcomeBranch, original: Ability, action: BattleActionContext,
    ) -> [BattleCardAssessment.ResourceUse] {
        let actor = action.actor
        var resources: [BattleCardAssessment.ResourceUse] = []
        if original.blockCost > 0 {
            resources.append(resourceUse(.block, amount: original.blockCost, actor: actor))
        }
        var hasDamage = false
        var hasManaEmpowerable = false
        for operation in branch.operations {
            if !hasDamage, operation.damageComponent != nil {
                hasDamage = true
            }
            if !hasManaEmpowerable, operation.isManaEmpowerable {
                hasManaEmpowerable = true
            }
            if hasDamage, hasManaEmpowerable {
                break
            }
        }
        let healthCost = BattleAbilityRules.healthCost(branch.operations, action: action, in: self)
        if healthCost > 0 {
            resources.append(resourceUse(.health, amount: healthCost, actor: actor))
        }
        for use in empowermentResourceUses(
            branch.operations, repeatsManaEmpowerment: original.repeatsManaEmpowerment,
            actor: actor, randomKeywords: branch.randomizeDamageKeywords,
            hasManaEmpowerable: hasManaEmpowerable, blockCost: original.blockCost,
        ) {
            mergeResource(use, into: &resources)
        }
        for (effectIndex, operation) in branch.operations.enumerated() {
            guard case let .effect(targeted) = operation, targeted.effect == .convertManaToBlock else { continue }
            guard targeted.chance > 0 else { continue }
            if let condition = targeted.condition, !BattleConditionEvaluator.isMet(condition, action: action, in: self) {
                continue
            }
            for (targetIndex, target) in action.targets(targeted.target, in: self).enumerated() where health(of: target) > 0 {
                // Earlier operations and another recipient's spending reactions can change this balance.
                let isCertain = targeted.chance >= 1 && !hasDamage && effectIndex == 0 && targetIndex == 0
                    && !hasManaEmpowerable
                let mana = mana(of: target)
                guard mana > 0 || !isCertain else { continue }
                mergeResource(resourceUse(.mana, amount: isCertain ? mana : nil, actor: target), into: &resources)
            }
        }
        return resources
    }
}

private extension BattleState {
    func empowermentResourceUses(
        _ operations: [AbilityOperation], repeatsManaEmpowerment: Bool,
        actor: Combatant, randomKeywords: Bool, hasManaEmpowerable: Bool, blockCost: Int,
    ) -> [BattleCardAssessment.ResourceUse] {
        guard hasManaEmpowerable || randomKeywords else { return [] }
        let blockOverride = blockCost > 0
            ? max(0, DefensePoolEngine.blockPoints(in: roster.activeEffects(for: actor)) - blockCost)
            : nil
        var budget = ManaEmpowermentBudget(
            keywords: randomKeywords ? [.freeze] : operations.flatMap(\.keywords),
            hasBurnDamage: !randomKeywords && operations.contains { $0.keyword == .burn && $0.isManaEmpowerable },
            repeatsManaEmpowerment: !randomKeywords && repeatsManaEmpowerment,
            actor: actor, in: self, blockOverride: blockOverride,
        )
        let isCertain = !randomKeywords && (budget.purchaseLimit == 1 || hasPredictableRepeatedPayments)
        guard let payment = budget.totalPayment() else { return [] }
        var uses: [BattleCardAssessment.ResourceUse] = []
        if payment.ownMana > 0 {
            uses.append(resourceUse(.mana, amount: isCertain ? payment.ownMana : nil, actor: actor))
        }
        if payment.partnerMana > 0, let partner = budget.partner {
            uses.append(resourceUse(.mana, amount: isCertain ? payment.partnerMana : nil, actor: partner))
        }
        if payment.block > 0 {
            uses.append(resourceUse(.block, amount: isCertain ? payment.block : nil, actor: actor))
        }
        return uses
    }

    var hasPredictableRepeatedPayments: Bool {
        func isPredictable(_ actorID: String) -> Bool {
            // Only these passive empowerment settings are modeled by the budget.
            // Other reactions can restore Mana, add Block, or interrupt later purchases.
            var triggers = modifiers(for: actorID).triggers
            triggers.repeatManaEmpowerment = false
            triggers.empowermentCostReduction = 0
            triggers.empowerBurnCostReduction = 0
            triggers.firstEmpowermentCostReduction = 0
            triggers.healingEmpowermentCostReduction = 0
            triggers.empowermentDamageBonus = 0
            triggers.freezeEmpowermentBlockPerMana = 0
            triggers.dragonPatronage = false
            triggers.prismaticScales = false
            triggers.flashFreeze = false
            return triggers == CombatTraitTriggers()
        }
        return isPredictable(roster.hero.id) && isPredictable(roster.companion.id)
    }

    func resourceUse(_ keyword: Keyword, amount: Int?, actor: Combatant) -> BattleCardAssessment.ResourceUse {
        let runtime = roster.runtime(for: actor)
        let balance: Int
        let capacity: Int
        switch keyword {
        case .health:
            balance = runtime?.currentHealth ?? 0
            capacity = runtime?.maxHealth ?? 0
        case .mana:
            balance = runtime?.currentMana ?? 0
            capacity = runtime?.maxMana ?? 0
        default:
            balance = runtime.map { DefensePoolEngine.blockPoints(in: $0.activeEffects) } ?? 0
            capacity = balance
        }
        return .init(combatantID: actor.id, keyword: keyword, amount: amount, balance: balance, capacity: capacity)
    }

    func mergeResource(_ use: BattleCardAssessment.ResourceUse, into resources: inout [BattleCardAssessment.ResourceUse]) {
        guard let index = resources.firstIndex(where: { $0.combatantID == use.combatantID && $0.keyword == use.keyword }) else {
            resources.append(use)
            return
        }
        let previous = resources[index]
        let amount = previous.amount.flatMap { first in use.amount.map { SaturatedArithmetic.saturatingAdd(first, $0) } }
        resources[index] = .init(
            combatantID: use.combatantID, keyword: use.keyword, amount: amount,
            balance: previous.balance, capacity: previous.capacity,
        )
    }
}
