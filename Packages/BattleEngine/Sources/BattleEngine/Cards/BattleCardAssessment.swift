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
        // Assessment never mutates combat, so every branch shares the same participants and override.
        let action = BattleActionContext(actor: actor, in: self)
        let possibilities = BattleAbilityRules.possibleOutcomes(card.ability, action: action, in: self)
        let selected = possibilities.ability
        let outcomes = possibilities.branches
        let keywordOverride = BattleTurnEngine.activeDamageKeywordOverride(for: actor, in: self)?.keyword
        var targets = outcomes.first.map {
            assessmentTargets($0, action: action, abilityID: selected.id, keywordOverride: keywordOverride)
        } ?? []
        // Intersect one branch at a time. Once no recipient is certain, later
        // branches cannot restore one and need no target projection.
        for branch in outcomes.dropFirst() {
            guard !targets.isEmpty else { break }
            let candidates = assessmentTargets(branch, action: action, abilityID: selected.id, keywordOverride: keywordOverride)
            var retained = 0
            for index in targets.indices {
                let target = targets[index]
                let common: BattleCardAssessment.Target
                if candidates.contains(target) {
                    common = target
                } else if case .damage = target.intent,
                          candidates.contains(where: { other in
                              guard other.combatantID == target.combatantID else { return false }
                              if case .damage = other.intent {
                                  return true
                              }
                              return false
                          }) {
                    common = .init(combatantID: target.combatantID, intent: .damage(nil))
                } else {
                    continue
                }
                targets[retained] = common
                retained += 1
            }
            targets.removeLast(targets.count - retained)
        }
        let uniqueTargets: [BattleCardAssessment.Target]
        if targets.count <= 1 {
            uniqueTargets = targets
        } else {
            var unique: [BattleCardAssessment.Target] = []
            for target in targets where !unique.contains(target) {
                unique.append(target)
            }
            uniqueTargets = unique
        }
        let resources: [BattleCardAssessment.ResourceUse]
        if outcomes.count == 1 {
            resources = assessmentResources(outcomes[0], original: selected, action: action)
        } else {
            let payments = outcomes.map { assessmentResources($0, original: selected, action: action) }
            resources = BattleCardAssessment.commonResources(payments)
        }
        return BattleCardAssessment(actorID: actor.id, denial: nil, targets: uniqueTargets, resources: resources)
    }
}

private extension BattleState {
    func assessmentTargets(
        _ branch: AbilityOutcomeBranch, action: BattleActionContext, abilityID: String, keywordOverride: Keyword?,
    ) -> [BattleCardAssessment.Target] {
        let actor = action.actor
        let hasDamage = branch.operations.contains { $0.damageComponent != nil }
        var targets = assessmentDamageTargets(branch, action: action, keywordOverride: keywordOverride)
        for (index, operation) in branch.operations.enumerated() {
            guard case let .effect(targeted) = operation else { continue }
            guard targeted.chance >= 1 else { continue }
            if let condition = targeted.condition, !BattleConditionEvaluator.isMet(condition, action: action, in: self) {
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
            if EffectApplication.selectsDrawPartner(abilityID: abilityID), case .drawCards = targeted.effect {
                continue
            }
            let recipientCanChange = hasDamage || index > 0
            if recipientCanChange, [.lowestHealthAlly, .defeatedAlly].contains(targeted.target) {
                continue
            }
            if case let .blessedAegis(block, holyDamage) = targeted.effect {
                for ally in action.allies(in: self) where health(of: ally) > 0 {
                    for effect in EffectApplication.aegisEffects(block: block, holyDamage: holyDamage) {
                        targets.append(.init(combatantID: ally.id, intent: .effect(effect)))
                    }
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
                targets.append(contentsOf: panaceaAssessmentTargets(baseHeal: baseHeal, action: action))
                continue
            }
            let target = action.target(targeted.target, in: self)
            targets.append(.init(combatantID: target.id, intent: .effect(targeted.effect)))
        }
        return targets
    }

    func assessmentDamageTargets(
        _ branch: AbilityOutcomeBranch, action: BattleActionContext, keywordOverride: Keyword?,
    ) -> [BattleCardAssessment.Target] {
        let actor = action.actor
        var targets: [BattleCardAssessment.Target] = []
        for operation in branch.operations {
            guard case let .damage(component) = operation else { continue }
            guard BattleDamageRules.isEnabled(component, action: action, in: self),
                  component.hasPotentialDamage else { continue }
            let target = action.target(component.target, in: self)
            guard target.id != actor.id else { continue }
            let keyword = keywordOverride ?? (branch.randomizeDamageKeywords ? nil : component.keyword)
            targets.append(.init(combatantID: target.id, intent: .damage(keyword)))
        }
        return targets
    }

    func panaceaAssessmentTargets(baseHeal: Int, action: BattleActionContext) -> [BattleCardAssessment.Target] {
        let cleanseTarget = EffectApplication.panaceaCleanseTarget(action: action, in: self)
        var targets: [BattleCardAssessment.Target] = [
            .init(combatantID: cleanseTarget.id, intent: .effect(.cleanse(nil))),
        ]
        // Cleanse can trigger damage and restoration before Panacea selects its recipient.
        if roster.hero.isAlive, roster.companion.isAlive,
           roster.activeEffects(for: cleanseTarget).contains(where: \.effect.isRemovableDebuff) {
            return targets
        }
        let healTarget = action.target(EffectApplication.panaceaHealTarget, in: self)
        targets.append(.init(combatantID: healTarget.id, intent: .effect(.instantHeal(.health, baseHeal))))
        return targets
    }
}

extension BattleCardAssessment {
    static func commonResources(_ outcomes: [[ResourceUse]]) -> [ResourceUse] {
        // A selected deterministic outcome already merged each payer's resource use.
        if outcomes.count == 1 {
            return outcomes[0]
        }
        var keys: [ResourceUse] = []
        for use in outcomes.lazy.flatMap(\.self) where !keys.contains(where: { $0.matches(use) }) {
            keys.append(use)
        }
        return keys.map { key in
            let firstAmount = key.quotedAmount(in: outcomes[0])
            let isCommon = outcomes.dropFirst().allSatisfy { outcome in
                let amount = key.quotedAmount(in: outcome)
                return amount == firstAmount
            }
            let amount = isCommon ? firstAmount : nil
            return ResourceUse(
                combatantID: key.combatantID, keyword: key.keyword, amount: amount,
                balance: key.balance, capacity: key.capacity,
            )
        }
    }
}

private extension BattleCardAssessment.ResourceUse {
    func quotedAmount(in outcome: [Self]) -> Int? {
        guard let use = outcome.first(where: { $0.matches(self) }) else { return 0 }
        return use.amount
    }

    func matches(_ other: Self) -> Bool {
        combatantID == other.combatantID && keyword == other.keyword
    }
}
