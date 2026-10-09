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
        let selected = BattleAbilityRules.resolveConditionalOutcome(card.ability, actor: actor, in: self)
        let outcomes = BattleAbilityRules.assessmentOutcomes(selected)
        // Assessment never mutates combat, so every branch shares the same participants and override.
        let action = BattleActionContext(actor: actor, in: self)
        let keywordOverride = BattleTurnEngine.activeDamageKeywordOverride(for: actor, in: self)?.keyword
        let candidates = outcomes.map {
            assessmentTargets($0, action: action, abilityID: selected.id, keywordOverride: keywordOverride)
        }
        var targets: [BattleCardAssessment.Target] = []
        for target in candidates.first ?? [] {
            let common: BattleCardAssessment.Target
            if candidates.dropFirst().allSatisfy({ $0.contains(target) }) {
                common = target
            } else if case .damage = target.intent,
                      candidates.dropFirst().allSatisfy({ branch in
                          branch.contains { other in
                              guard other.combatantID == target.combatantID else { return false }
                              if case .damage = other.intent {
                                  return true
                              }
                              return false
                          }
                      }) {
                common = .init(combatantID: target.combatantID, intent: .damage(nil))
            } else {
                continue
            }
            if !targets.contains(common) {
                targets.append(common)
            }
        }
        let payments = outcomes.map { assessmentResources($0, original: selected, action: action) }
        return BattleCardAssessment(
            actorID: actor.id, denial: nil, targets: targets,
            resources: BattleCardAssessment.commonResources(payments),
        )
    }
}

extension BattleAbilityRules {
    static func assessmentOutcomes(_ ability: Ability) -> [AbilityOutcomeBranch] {
        if let branches = ability.outcomeBranches {
            return branches
        }
        return [AbilityOutcomeBranch(operations: ability.operations)]
    }
}

private extension BattleState {
    func assessmentTargets(
        _ branch: AbilityOutcomeBranch, action: BattleActionContext, abilityID: String, keywordOverride: Keyword?,
    ) -> [BattleCardAssessment.Target] {
        let actor = action.actor
        let damageComponents = branch.damageComponents
        var targets: [BattleCardAssessment.Target] = []
        for component in damageComponents {
            let conditionMet = component.condition.map { BattleConditionEvaluator.isMet($0, actor: actor, in: self) } ?? true
            guard conditionMet || component.bonusAmount != 0,
                  component.hasPotentialDamage else { continue }
            let target = action.target(component.target, in: self)
            guard target.id != actor.id else { continue }
            let keyword = keywordOverride ?? (branch.randomizeDamageKeywords ? nil : component.keyword)
            targets.append(.init(combatantID: target.id, intent: .damage(keyword)))
        }
        for (index, targeted) in branch.targetedEffects.enumerated() {
            if let condition = targeted.condition, !BattleConditionEvaluator.isMet(condition, actor: actor, in: self) {
                continue
            }
            if case .partyDamageBonus = targeted.effect {
                let recipient = BattleAbilityRules.preparationRecipient(for: actor, in: self)
                targets.append(.init(combatantID: recipient.id, intent: .effect(targeted.effect)))
                continue
            }
            if case .drawAndPlayCards = targeted.effect {
                continue
            }
            // Pack Tactics chooses its draw owner after the hit and its reactions.
            if abilityID == Ability.packTactics.id, case .drawCards = targeted.effect {
                continue
            }
            let recipientCanChange = !damageComponents.isEmpty || index > 0
            if recipientCanChange, [.lowestHealthAlly, .defeatedAlly].contains(targeted.target) {
                continue
            }
            if case let .blessedAegis(block, holyDamage) = targeted.effect {
                for ally in action.allies(in: self) where health(of: ally) > 0 {
                    targets.append(.init(combatantID: ally.id, intent: .effect(.shield(.block, block))))
                    targets.append(.init(combatantID: ally.id, intent: .effect(.onHitDamage(.holy, holyDamage))))
                }
                continue
            }
            if targeted.target == .eachAlly {
                for ally in action.allies(in: self) where health(of: ally) > 0 {
                    targets.append(.init(combatantID: ally.id, intent: .effect(targeted.effect)))
                }
                continue
            }
            if case let .panacea(baseHeal, _) = targeted.effect {
                guard !recipientCanChange else { continue }
                targets.append(contentsOf: panaceaAssessmentTargets(baseHeal: baseHeal, actor: actor))
                continue
            }
            let target = action.target(targeted.target, in: self)
            targets.append(.init(combatantID: target.id, intent: .effect(targeted.effect)))
        }
        return targets
    }

    func panaceaAssessmentTargets(baseHeal: Int, actor: Combatant) -> [BattleCardAssessment.Target] {
        let cleanseTarget = BattleConditionEvaluator.mostDebuffedAlly(in: self)
        var targets: [BattleCardAssessment.Target] = [
            .init(combatantID: cleanseTarget.id, intent: .effect(.cleanse(nil))),
        ]
        // Fresh Batch and its healing reactions resolve before Panacea selects its recipient.
        if modifiers(for: actor.id).triggers.freshBatch,
           roster.activeEffects(for: cleanseTarget).contains(where: \.effect.isRemovableDebuff) {
            return targets
        }
        let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: self)
        targets.append(.init(combatantID: healTarget.id, intent: .effect(.instantHeal(.health, baseHeal))))
        return targets
    }
}

extension BattleCardAssessment {
    static func commonResources(_ outcomes: [[ResourceUse]]) -> [ResourceUse] {
        var keys: [ResourceUse] = []
        for use in outcomes.lazy.flatMap(\.self) where !keys.contains(where: { $0.matches(use) }) {
            keys.append(use)
        }
        return keys.map { key in
            let amounts = outcomes.map { outcome -> Int? in
                guard let use = outcome.first(where: { $0.matches(key) }) else { return 0 }
                return use.amount
            }
            let firstAmount = amounts[0]
            let amount = amounts.allSatisfy { $0 == firstAmount } ? firstAmount : nil
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
