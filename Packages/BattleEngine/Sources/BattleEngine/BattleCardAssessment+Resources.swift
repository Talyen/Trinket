import TrinketContent
import TrinketCore

extension BattleState {
    func assessmentResources(
        _ branch: AbilityOutcomeBranch, original: Ability, actor: Combatant,
    ) -> [BattleCardAssessment.ResourceUse] {
        var resources: [BattleCardAssessment.ResourceUse] = []
        let healthCost = BattleAbilityRules.healthCost(branch.damageComponents, actor: actor, in: self)
        if healthCost > 0 {
            resources.append(resourceUse(.health, amount: healthCost, actor: actor))
        }
        let ability = Ability(
            id: original.id, name: original.name, tier: original.tier,
            damageComponents: branch.damageComponents, targetedEffects: branch.targetedEffects,
            repeatsManaEmpowerment: original.repeatsManaEmpowerment,
        )
        resources.append(contentsOf: empowermentResourceUses(ability, actor: actor, randomKeywords: branch.randomizeDamageKeywords))
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: self)
        for (index, targeted) in branch.targetedEffects.enumerated() where targeted.effect == .convertManaToBlock {
            if let condition = targeted.condition, !BattleConditionEvaluator.isMet(condition, actor: actor, in: self) {
                continue
            }
            let target = BattleTargetResolver.effectTarget(targeted.target, actor: actor, abilityTarget: abilityTarget, in: self)
            let mana = mana(of: target)
            guard mana > 0 else { continue }
            let isCertain = branch.damageComponents.isEmpty && index == 0
            mergeResource(resourceUse(.mana, amount: isCertain ? mana : nil, actor: target), into: &resources)
        }
        return resources
    }
}

private extension BattleState {
    func empowermentResourceUses(_ ability: Ability, actor: Combatant, randomKeywords: Bool) -> [BattleCardAssessment.ResourceUse] {
        guard ability.hasManaEmpowerableBurnOrFreezeDamage || randomKeywords else { return [] }
        let quoted = randomKeywords ? Ability(
            id: ability.id, name: ability.name, tier: ability.tier,
            directDamage: 1, damageKeyword: .freeze,
        ) : ability
        var budget = ManaEmpowermentBudget(ability: quoted, actor: actor, in: self)
        let isCertain = !randomKeywords && (budget.purchaseLimit == 1 || hasPredictableRepeatedPayments)
        var ownMana = 0
        var sharedMana = 0
        var block = 0
        for _ in 0 ..< budget.purchaseLimit {
            guard let payment = budget.nextPayment() else { break }
            ownMana += payment.ownMana
            sharedMana += payment.partnerMana
            block += payment.block
        }
        var uses: [BattleCardAssessment.ResourceUse] = []
        if ownMana > 0 {
            uses.append(resourceUse(.mana, amount: isCertain ? ownMana : nil, actor: actor))
        }
        if sharedMana > 0, let partner = budget.partner {
            uses.append(resourceUse(.mana, amount: isCertain ? sharedMana : nil, actor: partner))
        }
        if block > 0 {
            uses.append(resourceUse(.block, amount: isCertain ? block : nil, actor: actor))
        }
        return uses
    }

    var hasPredictableRepeatedPayments: Bool {
        [roster.hero, roster.companion].allSatisfy { runtime in
            var triggers = modifiers(for: runtime.id).triggers
            triggers.repeatManaEmpowerment = false
            triggers.empowermentCostReduction = 0
            triggers.firstEmpowermentCostReduction = 0
            triggers.healingEmpowermentCostReduction = 0
            triggers.empowermentDamageBonus = 0
            triggers.freezeEmpowermentBlockPerMana = 0
            triggers.dragonPatronage = false
            triggers.prismaticScales = false
            triggers.flashFreeze = false
            return triggers == CombatTraitTriggers()
        }
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
        let amount = previous.amount.flatMap { first in use.amount.map { first + $0 } }
        resources[index] = .init(
            combatantID: use.combatantID, keyword: use.keyword, amount: amount,
            balance: use.balance, capacity: use.capacity,
        )
    }
}
