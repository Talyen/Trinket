import TrinketContent
import TrinketCore

public struct BattleCardAssessment: Equatable, Sendable {
    public enum Intent: Hashable, Sendable {
        case damage(Keyword?)
        case effect(Effect)
    }

    public struct Target: Hashable, Sendable {
        public let combatantID: String
        public let intent: Intent
    }

    public struct ResourceUse: Equatable, Sendable {
        public let combatantID: String
        public let keyword: Keyword
        public let amount: Int?
        public let balance: Int
        public let capacity: Int
    }

    public let actorID: String
    public let denial: BattlePlayError?
    public let targets: [Target]
    public let resources: [ResourceUse]
}

public extension BattleState {
    func assessCard(_ card: BattleCard) -> BattleCardAssessment {
        let actor = roster[card.owner].combatant
        let denial = hand.card(id: card.id) == card
            ? BattleCardCombatEngine.playError(for: card, in: self) : .cardNotInHand
        guard denial == nil else {
            return BattleCardAssessment(actorID: actor.id, denial: denial, targets: [], resources: [])
        }
        let outcomes = BattleAbilityRules.assessmentOutcomes(card.ability, actor: actor, in: self)
        let candidates = outcomes.map { assessmentTargets($0, actor: actor) }
        let common = (candidates.first ?? []).filter { target in candidates.allSatisfy { $0.contains(target) } }
        var targets: [BattleCardAssessment.Target] = []
        for target in common where !targets.contains(target) {
            targets.append(target)
        }
        let payments = outcomes.map { assessmentResources($0, original: card.ability, actor: actor) }
        return BattleCardAssessment(
            actorID: actor.id, denial: nil, targets: targets,
            resources: BattleCardAssessment.commonResources(payments),
        )
    }
}

extension BattleAbilityRules {
    static func assessmentOutcomes(_ ability: Ability, actor: Combatant, in context: BattleState) -> [AbilityOutcomeBranch] {
        if let branches = ability.outcomeBranches {
            let eligible = eligibleOutcomes(branches, actor: actor, in: context)
            if !eligible.isEmpty {
                return eligible
            }
        }
        return [AbilityOutcomeBranch(damageComponents: ability.damageComponents, targetedEffects: ability.targetedEffects)]
    }
}

private extension BattleState {
    func assessmentTargets(_ branch: AbilityOutcomeBranch, actor: Combatant) -> [BattleCardAssessment.Target] {
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: self)
        let keywordOverride = BattleTurnEngine.activeDamageKeywordOverride(for: actor, in: self)?.keyword
        var targets: [BattleCardAssessment.Target] = []
        for component in branch.damageComponents {
            let conditionMet = component.condition.map { BattleConditionEvaluator.isMet($0, actor: actor, in: self) } ?? true
            guard conditionMet || component.bonusAmount != 0,
                  component.amount + (conditionMet ? component.bonusAmount : 0) > 0 else { continue }
            let target = BattleTargetResolver.effectTarget(component.target, actor: actor, abilityTarget: abilityTarget, in: self)
            guard target.id != actor.id else { continue }
            let keyword = keywordOverride ?? (branch.randomizeDamageKeywords ? nil : component.keyword)
            targets.append(.init(combatantID: target.id, intent: .damage(keyword)))
        }
        for (index, targeted) in branch.targetedEffects.enumerated() {
            if let condition = targeted.condition, !BattleConditionEvaluator.isMet(condition, actor: actor, in: self) {
                continue
            }
            let recipientCanChange = !branch.damageComponents.isEmpty || index > 0
            if recipientCanChange, [.lowestHealthAlly, .defeatedAlly].contains(targeted.target) {
                continue
            }
            if case let .panacea(baseHeal, _) = targeted.effect {
                guard !recipientCanChange else { continue }
                let cleanseTarget = BattleConditionEvaluator.mostDebuffedAlly(in: self)
                let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: self)
                targets.append(.init(combatantID: cleanseTarget.id, intent: .effect(.cleanse(nil))))
                targets.append(.init(combatantID: healTarget.id, intent: .effect(.instantHeal(.health, baseHeal))))
                continue
            }
            let target = BattleTargetResolver.effectTarget(targeted.target, actor: actor, abilityTarget: abilityTarget, in: self)
            targets.append(.init(combatantID: target.id, intent: .effect(targeted.effect)))
        }
        return targets
    }
}

extension BattleCardAssessment {
    static func commonResources(_ outcomes: [[ResourceUse]]) -> [ResourceUse] {
        var keys: [ResourceUse] = []
        for use in outcomes.flatMap(\.self) where !keys.contains(where: { $0.matches(use) }) {
            keys.append(use)
        }
        return keys.map { key in
            let amounts = outcomes.map { outcome in outcome.first(where: { $0.matches(key) })?.amount ?? 0 }
            let uncertain = outcomes.contains { outcome in outcome.contains { $0.matches(key) && $0.amount == nil } }
            let amount = !uncertain && amounts.allSatisfy { $0 == amounts.first } ? amounts.first : nil
            return ResourceUse(
                combatantID: key.combatantID, keyword: key.keyword, amount: amount,
                balance: key.balance, capacity: key.capacity,
            )
        }
    }
}

private extension BattleCardAssessment.ResourceUse {
    func matches(_ other: Self) -> Bool {
        combatantID == other.combatantID && keyword == other.keyword
    }
}
