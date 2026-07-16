import Foundation
import TrinketCore

/// Closed vocabulary for combat floating chips. The glyph atlas and composer only
/// accept these shapes — never free-form strings on the display-link path.
enum CombatFeedbackChipLabel: Hashable {
    /// Signed numeric chip such as `-12` or `+8`.
    case amount(Int)
    /// Signed percent chip such as `+25%`.
    case percent(Int)
    /// Non-numeric chip such as `Dodge` or `Stunned!`.
    case word(CombatFeedbackChipWord)

    var displayString: String {
        switch self {
        case let .amount(value):
            Self.formatAmount(value)
        case let .percent(value):
            Self.formatPercent(value)
        case let .word(word):
            word.displayString
        }
    }

    static func formatAmount(_ value: Int) -> String {
        if value > 0 {
            return "+\(value)"
        }
        return "\(value)"
    }

    static func formatPercent(_ value: Int) -> String {
        "\(formatAmount(value))%"
    }

    /// Builds a label from an `ActionEventDisplay` using the same first-token rule as
    /// the previous floating-text path (numeric token → amount/percent; else full word).
    static func fromDisplayText(_ text: String) -> CombatFeedbackChipLabel? {
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

    var displayString: String {
        switch self {
        case .dodge:
            "Dodge"
        case .critical:
            "Critical"
        case let .plain(keyword):
            keyword.rawValue
        case let .applied(keyword):
            "+\(keyword.rawValue)"
        case let .triggered(keyword):
            "\(keyword.statusAlias ?? keyword.rawValue)!"
        case let .cleanse(keyword):
            "Cleanse \(keyword.statusAlias ?? keyword.rawValue)"
        case let .purge(keyword):
            "Purge \(keyword.rawValue)"
        case let .halve(keyword):
            "Halve \(keyword.rawValue)"
        }
    }

    static func parse(_ text: String) -> CombatFeedbackChipWord? {
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

    /// Exhaustive word cases for atlas prewarm.
    static var allAtlasCases: [CombatFeedbackChipWord] {
        var words: [CombatFeedbackChipWord] = [.dodge, .critical]
        for keyword in Keyword.allCases {
            words.append(.plain(keyword))
            words.append(.applied(keyword))
            words.append(.triggered(keyword))
            words.append(.cleanse(keyword))
            words.append(.purge(keyword))
            words.append(.halve(keyword))
        }
        return words
    }
}
