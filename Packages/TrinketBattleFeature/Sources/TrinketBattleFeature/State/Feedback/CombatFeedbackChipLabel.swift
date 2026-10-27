import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureSupport

enum CombatFeedbackChipLabel: Hashable {
    static let numericAtlasFragments = ["+"] + (0 ... 9).map(String.init)

    case amount(Int, additive: Bool = true)
    case word(CombatFeedbackChipWord)
    case reaction(CombatReaction)
    case reactionPayoff(CombatReaction, Int)

    func merging(with other: Self) -> Self? {
        switch (self, other) {
        case let (.amount(lhs, lhsAdditive), .amount(rhs, rhsAdditive)):
            guard lhsAdditive, rhsAdditive, (lhs >= 0) == (rhs >= 0) else { return nil }
            return .amount(SaturatedArithmetic.saturatingAdd(lhs, rhs))
        case let (.word(lhsWord), .word(rhsWord)):
            return lhsWord == rhsWord ? .word(lhsWord) : nil
        default:
            return nil
        }
    }

    var displayString: String {
        switch self {
        case let .amount(value, _):
            Self.formatAmount(value)
        case let .reaction(reaction):
            String(localized: reaction.nameResource)
        case let .reactionPayoff(reaction, amount):
            "\(String(localized: reaction.nameResource)) \(Self.formatAmount(amount))"
        case .word:
            ""
        }
    }

    static func formatAmount(_ value: Int) -> String {
        String(value.magnitude)
    }

    static func from(event: ActionEvent) -> Self? {
        switch event.kind {
        case .abilityDamage, .status:
            .amount(-event.amount)
        case let .reaction(reaction):
            .reaction(reaction)
        case .ability, .milestone:
            nil
        case let .effect(outcome):
            CombatFeedbackEffectPresentation.descriptor(for: outcome).label(amount: event.amount, keyword: event.keyword)
        }
    }

    var isZeroNumeric: Bool {
        switch self {
        case let .amount(value, _):
            value == 0
        case .word, .reaction, .reactionPayoff:
            false
        }
    }
}

enum CombatFeedbackStatusLabel: String, CaseIterable, Hashable {
    case leech = "Leech"
    case amplified = "Amplified"
    case thorns = "Thorns"
    case criticalUp = "Critical Up"
    case manaShield = "Mana Shield"
    case consecrated = "Consecrated"
    case nextHolyStrike = "Next Holy Strike"
    case nextStrikeDouble = "Double Damage"
    case playNextCardTwice = "Repeat Card"
    case kindled = "Kindled"
    case evadeNextHit = "Evade"
    case marked = "Marked"
    case blockDown = "Block Down"
    case ward = "Ward"
    case avatar = "Avatar"
    case hemorrhage = "Hemorrhage"
}

enum CombatFeedbackChipWord: Hashable {
    case dodge
    case plain(Keyword)
    case applied(Keyword)
    case triggered(Keyword)
    case cleanse(Keyword)
    case purge(Keyword)
    case status(CombatFeedbackStatusLabel)
}
