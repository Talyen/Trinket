import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureSupport

/// Closed vocabulary for combat floating chips. The glyph atlas and composer only
/// accept these shapes — never free-form strings on the display-link path.
enum CombatFeedbackChipLabel: Hashable {
    static let numericAtlasFragments = ["+", "%"] + (0 ... 9).map(String.init)

    /// Numeric chip displayed as a magnitude.
    case amount(Int)
    /// Percent chip displayed as a magnitude.
    case percent(Int)
    /// Non-numeric chip such as dodge, cleanse, or a short keyword word.
    case word(CombatFeedbackChipWord)

    /// Visible chip text for numeric chips and short keyword words. Icon-only /
    /// dual-icon chips return an empty string (see `CombatFeedbackChipPresentation`).
    var displayString: String {
        switch self {
        case let .amount(value):
            Self.formatAmount(value)
        case let .percent(value):
            Self.formatPercent(value)
        case let .word(word):
            word.composeText ?? ""
        }
    }

    /// Atlas fragments needed to render this label. Numeric chips use the complete
    /// prewarmed digit alphabet so magnitude blits never wait on glyph baking.
    /// Full chip rasters for specific amounts are still composed on demand (or from
    /// the closed-vocabulary catalog for non-numeric chips).
    var atlasFragments: [String] {
        switch self {
        case .amount, .percent:
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

    static func formatPercent(_ value: Int) -> String {
        "\(formatAmount(value))%"
    }

    /// Chip vocabulary from the engine event — never from formatted log text.
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
        return switch effectKind {
        case .thornsApplied: .thorns
        case .criticalChanceApplied: .criticalUp
        case .manaShieldApplied: .manaShield
        case .damageKeywordOverrideApplied: .consecrated
        case .nextHolyStrikeApplied: .nextHolyStrike
        case .nextStrikeDoubleApplied: .nextStrikeDouble
        case .evadeNextHitApplied: .evadeNextHit
        case .markedApplied: .marked
        case .leechApplied: .leech
        case .shieldHalved: .blockDown
        default: nil
        }
    }

    private static func from(
        effectKind: ActionEvent.EffectKind,
        event: ActionEvent
    ) -> Self? {
        switch effectKind {
        case .instantHeal, .leechHeal, .resourceGain, .shieldApplied, .manaShieldTriggered,
             .cardsDrawn:
            .amount(event.amount)
        case .shieldAbsorbed, .thornsTriggered, .markedConsumed:
            .amount(-event.amount)
        case .dodgeApplied:
            .word(.dodge)
        case .cleanseApplied:
            .word(.cleanse(event.keyword))
        case .purgeApplied:
            .word(.purge(event.keyword))
        case .deathsDoorTriggered, .deathsDoorExpired:
            .word(.plain(.deathsDoor))
        case .controlActionSkipped:
            .word(.plain(event.keyword))
        case .controlTriggered:
            .word(.triggered(event.keyword))
        case .controlApplied:
            .word(.applied(event.keyword))
        case .thornsApplied, .criticalChanceApplied, .manaShieldApplied,
             .damageKeywordOverrideApplied, .nextHolyStrikeApplied, .nextStrikeDoubleApplied,
             .evadeNextHitApplied, .markedApplied, .leechApplied, .shieldHalved:
            nil
        }
    }

    var isZeroNumeric: Bool {
        switch self {
        case let .amount(value), let .percent(value):
            value == 0
        case .word:
            false
        }
    }

    var isNegativeNumeric: Bool {
        switch self {
        case let .amount(value), let .percent(value):
            value < 0
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
    case evadeNextHit = "Evade"
    case marked = "Marked"
    case blockDown = "Block Down"
    case leech = "Leech"
}

/// Closed set of non-numeric chip phrases produced by battle presentation.
enum CombatFeedbackChipWord: Hashable {
    case dodge
    case critical
    case plain(Keyword)
    case applied(Keyword)
    case triggered(Keyword)
    case cleanse(Keyword)
    case purge(Keyword)
    case halve(Keyword)
    case status(CombatFeedbackStatusLabel)

    /// Short text drawn next to the keyword icon. `nil` means icon-only or dual-icon.
    var composeText: String? {
        switch self {
        case .dodge, .cleanse, .purge, .halve, .status:
            nil
        case .critical:
            "Critical"
        case let .plain(keyword):
            keyword == .deathsDoor ? nil : keyword.rawValue
        case let .applied(keyword):
            keyword.rawValue
        case let .triggered(keyword):
            keyword.rawValue
        }
    }

    /// Exhaustive word cases that still need a text fragment in the glyph atlas.
    static var textAtlasCases: [Self] {
        var words: [Self] = [.critical]
        for keyword in Keyword.allCases where keyword != .deathsDoor {
            words.append(.plain(keyword))
            words.append(.applied(keyword))
            words.append(.triggered(keyword))
        }
        return words
    }
}
