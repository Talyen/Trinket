import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureSupport

enum CombatFeedbackChipLabel: Hashable {
    static let numericAtlasFragments = ["+"] + (0 ... 9).map(String.init)

    case amount(Int)
    case word(CombatFeedbackChipWord)

    func merging(with other: Self) -> Self? {
        switch (self, other) {
        case let (.amount(lhs), .amount(rhs)):
            guard (lhs >= 0) == (rhs >= 0) else { return nil }
            return .amount(lhs + rhs)
        case let (.word(lhsWord), .word(rhsWord)):
            return lhsWord == rhsWord ? .word(lhsWord) : nil
        default:
            return nil
        }
    }

    var displayString: String {
        switch self {
        case let .amount(value):
            Self.formatAmount(value)
        case let .word(word):
            word.composeText ?? ""
        }
    }

    var atlasFragments: [String] {
        switch self {
        case .amount:
            displayString.map(String.init)
        case let .word(word):
            if let text = word.composeText {
                [text]
            } else {
                []
            }
        }
    }

    static func formatAmount(_ value: Int) -> String {
        String(value.magnitude)
    }

    static func from(event: ActionEvent) -> Self? {
        if let status = statusLabel(for: event) {
            return .word(.status(status))
        }
        switch event.kind {
        case .abilityDamage, .status:
            return .amount(-event.amount)
        case .ability, .milestone:
            return nil
        case .effect:
            guard let effectKind = event.effectKind else {
                return .word(.plain(event.keyword))
            }
            return from(effectKind: effectKind, event: event)
        }
    }

    private static func statusLabel(for event: ActionEvent) -> CombatFeedbackStatusLabel? {
        guard let effectKind = event.effectKind else { return nil }
        return CombatFeedbackEffectPresentation.descriptor(for: effectKind).statusLabel
    }

    private static func from(
        effectKind: ActionEvent.EffectOutcome,
        event: ActionEvent,
    ) -> Self? {
        guard let rule = CombatFeedbackEffectPresentation.descriptor(for: effectKind).labelRule else {
            return nil
        }
        switch rule {
        case .amount:
            return .amount(event.amount)
        case .negatedAmount:
            return .amount(-event.amount)
        case .dodgeWord:
            return .word(.dodge)
        case .plainKeyword:
            return .word(.plain(event.keyword))
        case .appliedKeyword:
            return .word(.applied(event.keyword))
        case .triggeredKeyword:
            return .word(.triggered(event.keyword))
        case .cleanseKeyword:
            return .word(.cleanse(event.keyword))
        case .purgeKeyword:
            return .word(.purge(event.keyword))
        case .deathsDoorIcon:
            return .word(.plain(.deathsDoor))
        }
    }

    var isZeroNumeric: Bool {
        switch self {
        case let .amount(value):
            value == 0
        case .word:
            false
        }
    }
}

enum CombatFeedbackStatusLabel: String, CaseIterable, Hashable {
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

    var composeText: String? {
        switch self {
        case .dodge, .cleanse, .purge, .status:
            nil
        case let .plain(keyword):
            keyword == .deathsDoor ? nil : keyword.rawValue
        case let .applied(keyword):
            keyword.rawValue
        case let .triggered(keyword):
            keyword.rawValue
        }
    }
}
