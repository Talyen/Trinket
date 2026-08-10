import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureSupport

/// Closed vocabulary for combat floating chips. The glyph atlas and composer only
/// accept these shapes — never free-form strings on the display-link path.
enum CombatFeedbackChipLabel: Hashable {
    static let numericAtlasFragments = ["+", "%"] + (0 ... 9).map(String.init)

    /// Numeric chip sourced from a signed formatter token and displayed as a magnitude.
    case amount(Int)
    /// Percent chip sourced from a signed formatter token and displayed as a magnitude.
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

    /// Builds a label from an `ActionEventDisplay` using the same first-token rule as
    /// the previous floating-text path (numeric token → amount/percent; else full word).
    static func fromDisplayText(_ text: String) -> Self? {
        guard !text.isEmpty else { return nil }
        guard let firstToken = text.split(separator: " ").first else { return nil }
        let token = String(firstToken)
        if token.contains(where: \.isNumber) {
            if token.hasSuffix("%"), let value = parseSignedInt(String(token.dropLast())) {
                return .percent(value)
            }
            if let value = parseSignedInt(token) {
                return .amount(value)
            }
            assertionFailure("Numeric floating token was not a closed amount/percent: \(token)")
            return nil
        }
        guard let word = CombatFeedbackChipWord.parse(text) else {
            assertionFailure("Unmapped combat chip word: \(text)")
            return nil
        }
        return .word(word)
    }

    private static func parseSignedInt(_ raw: String) -> Int? {
        Int(raw)
    }

    var isZeroNumeric: Bool {
        switch self {
        case let .amount(value), let .percent(value):
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
    case evadeNextHit = "Evade"
    case marked = "Marked"
    case blockDown = "Block Down"
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

    static func parse(_ text: String) -> Self? {
        switch text {
        case "Dodge":
            return .dodge
        case "Critical":
            return .critical
        default:
            break
        }

        if text.hasPrefix("Cleanse ") {
            let rest = String(text.dropFirst("Cleanse ".count))
            if let keyword = keywordMatching(rest) {
                return .cleanse(keyword)
            }
        }
        if text.hasPrefix("Purge ") {
            let rest = String(text.dropFirst("Purge ".count))
            if let keyword = Keyword(rawValue: rest) {
                return .purge(keyword)
            }
        }
        if text.hasPrefix("Halve ") {
            let rest = String(text.dropFirst("Halve ".count))
            if let keyword = Keyword(rawValue: rest) {
                return .halve(keyword)
            }
        }
        if let label = CombatFeedbackStatusLabel(rawValue: text) {
            return .status(label)
        }
        if text.hasPrefix("+"), let keyword = Keyword(rawValue: String(text.dropFirst())) {
            return .applied(keyword)
        }
        if text.hasSuffix("!") {
            let stem = String(text.dropLast())
            if let keyword = keywordMatching(stem) {
                return .triggered(keyword)
            }
        }
        if let keyword = Keyword(rawValue: text) {
            return .plain(keyword)
        }
        return nil
    }

    private static func keywordMatching(_ label: String) -> Keyword? {
        if let keyword = Keyword(rawValue: label) {
            return keyword
        }
        return Keyword.allCases.first { $0.statusAlias == label }
    }
}
