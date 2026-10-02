import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureSupport

enum CombatFeedbackChipLabel: Hashable {
    static let numericAtlasFragments = ["+"] + (0 ... 9).map(String.init)

    case amount(Int, additive: Bool = true)
    case word(CombatFeedbackChipWord)

    func merging(with other: Self) -> Self? {
        switch (self, other) {
        case let (.amount(lhs, lhsAdditive), .amount(rhs, rhsAdditive)):
            guard lhsAdditive, rhsAdditive, (lhs >= 0) == (rhs >= 0) else { return nil }
            return .amount(lhs + rhs)
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
        case .word:
            ""
        }
    }

    static func formatAmount(_ value: Int) -> String {
        String(value.magnitude)
    }

    static func from(event: ActionEvent) -> Self? {
        let descriptor = event.effectKind.map { CombatFeedbackEffectPresentation.descriptor(for: $0) }
        if case let .status(status)? = descriptor?.labelRule {
            return .word(.status(status))
        }
        switch event.kind {
        case .abilityDamage, .status:
            return .amount(-event.amount)
        case .ability, .milestone:
            return nil
        case .effect:
            guard let descriptor else {
                return .word(.plain(event.keyword))
            }
            return from(descriptor: descriptor, event: event)
        }
    }

    private static func from(
        descriptor: CombatFeedbackEffectPresentation.Descriptor,
        event: ActionEvent,
    ) -> Self? {
        switch descriptor.labelRule {
        case .none:
            nil
        case let .status(status):
            .word(.status(status))
        case .amount:
            .amount(event.amount, additive: descriptor.isAdditive)
        case .negatedAmount:
            .amount(-event.amount)
        case .dodgeWord:
            .word(.dodge)
        case .plainKeyword:
            .word(.plain(event.keyword))
        case .appliedKeyword:
            .word(.applied(event.keyword))
        case .triggeredKeyword:
            .word(.triggered(event.keyword))
        case .cleanseKeyword:
            .word(.cleanse(event.keyword))
        case .purgeKeyword:
            .word(.purge(event.keyword))
        case .deathsDoorIcon:
            .word(.plain(.deathsDoor))
        }
    }

    var isZeroNumeric: Bool {
        switch self {
        case let .amount(value, _):
            value == 0
        case .word:
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
