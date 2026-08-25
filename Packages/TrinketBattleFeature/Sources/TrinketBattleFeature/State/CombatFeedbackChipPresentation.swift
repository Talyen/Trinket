import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Resolved glyphs + optional short text for one combat floating chip.
/// Dual-symbol chips use independent tints (e.g. purple sparkles + Bleed red).
struct CombatFeedbackChipPresentation: Hashable {
    enum Style: Hashable {
        case keyword(Keyword)
        case beneficialStatus
        case negativeStatus

        var visualStyle: Keyword.VisualStyle {
            switch self {
            case let .keyword(keyword): keyword.visualStyle
            case .beneficialStatus: .beneficialStatus
            case .negativeStatus: .negativeStatus
            }
        }
    }

    let leadingStyle: Style?
    let trailingStyle: Style
    /// Visible chip text. `nil` for icon-only / dual-icon chips.
    let text: String?

    static func resolve(
        label: CombatFeedbackChipLabel,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass
    ) -> Self {
        switch label {
        case .amount:
            let style = trailingStyle(
                keyword: keyword,
                visualRole: visualRole,
                feedbackClass: feedbackClass
            )
            return Self(
                leadingStyle: nil,
                trailingStyle: style,
                text: label.displayString
            )
        case let .word(word):
            return resolveWord(
                word,
                keyword: keyword
            )
        }
    }

    private static func resolveWord(
        _ word: CombatFeedbackChipWord,
        keyword: Keyword
    ) -> Self {
        switch word {
        case .dodge:
            iconOnly(trailing: .keyword(.dodge))
        case let .plain(chipKeyword):
            if chipKeyword == .deathsDoor {
                iconOnly(trailing: .keyword(.deathsDoor))
            } else {
                textAndIcon(trailing: .keyword(chipKeyword), text: chipKeyword.rawValue)
            }
        case let .applied(chipKeyword):
            textAndIcon(trailing: .keyword(chipKeyword), text: chipKeyword.rawValue)
        case let .triggered(chipKeyword):
            textAndIcon(trailing: .keyword(chipKeyword), text: chipKeyword.rawValue)
        case let .cleanse(chipKeyword):
            dualAction(leading: .keyword(.purge), trailing: .keyword(chipKeyword))
        case let .purge(chipKeyword):
            dualAction(leading: .keyword(.purge), trailing: .keyword(chipKeyword))
        case let .status(status):
            resolveStatus(status, keyword: keyword)
        }
    }

    private static func textAndIcon(
        trailing: Style,
        text: String
    ) -> Self {
        Self(
            leadingStyle: nil,
            trailingStyle: trailing,
            text: text
        )
    }

    private static func resolveStatus(
        _ status: CombatFeedbackStatusLabel,
        keyword: Keyword
    ) -> Self {
        let beneficial = Style.beneficialStatus
        let negative = Style.negativeStatus
        switch status {
        case .consecrated, .nextHolyStrike, .avatar:
            return dualAction(leading: beneficial, trailing: .keyword(.holy))
        case .nextStrikeDouble:
            return dualAction(leading: beneficial, trailing: .keyword(.physical))
        case .evadeNextHit:
            return dualAction(leading: beneficial, trailing: .keyword(.dodge))
        case .manaShield:
            return dualAction(leading: beneficial, trailing: .keyword(.mana))
        case .criticalUp, .thorns:
            return dualAction(leading: beneficial, trailing: .keyword(.physical))
        case .ward:
            return dualAction(leading: beneficial, trailing: .keyword(keyword))
        case .blockDown:
            return dualAction(leading: negative, trailing: .keyword(.block))
        case .marked:
            return iconOnly(trailing: negative)
        case .hemorrhage:
            return dualAction(leading: negative, trailing: .keyword(.bleed))
        }
    }

    private static func iconOnly(trailing: Style) -> Self {
        Self(
            leadingStyle: nil,
            trailingStyle: trailing,
            text: nil
        )
    }

    private static func dualAction(
        leading: Style,
        trailing: Style
    ) -> Self {
        Self(
            leadingStyle: leading,
            trailingStyle: trailing,
            text: nil
        )
    }

    private static func trailingStyle(
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass
    ) -> Style {
        switch visualRole {
        case .beneficialStatus:
            return .beneficialStatus
        case .negativeStatus:
            return .negativeStatus
        case .keyword:
            break
        }

        return switch feedbackClass {
        case .heal: .keyword(.health)
        case .resource: .keyword(keyword == .mana ? .mana : .gold)
        case .block: .keyword(.block)
        case .dodge: .keyword(.dodge)
        case .control: .keyword(keyword)
        case .deathsDoor: .keyword(.deathsDoor)
        case .directDamage, .critical, .dot, .buff: .keyword(keyword)
        }
    }
}

extension CombatFeedbackItem {
    var chipPresentation: CombatFeedbackChipPresentation {
        CombatFeedbackChipPresentation.resolve(
            label: label,
            keyword: keyword,
            visualRole: visualRole,
            feedbackClass: feedbackClass
        )
    }
}
