import Foundation
import TrinketCore
import TrinketDesignSystem

/// Resolved glyphs + optional short text for one combat floating chip.
/// Dual-symbol chips use independent tints (e.g. purple sparkles + Bleed red).
struct CombatFeedbackChipPresentation {
    let leadingSymbolName: String?
    let leadingTint: Keyword.VisualStyle?
    let trailingSymbolName: String
    let trailingTint: Keyword.VisualStyle
    /// Visible chip text. `nil` for icon-only / dual-icon chips.
    let text: String?

    static func resolve(
        label: CombatFeedbackChipLabel,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackChipPresentation {
        switch label {
        case .amount, .percent:
            let tint = trailingStyle(
                keyword: keyword,
                visualRole: visualRole,
                feedbackClass: feedbackClass
            )
            return CombatFeedbackChipPresentation(
                leadingSymbolName: nil,
                leadingTint: nil,
                trailingSymbolName: tint.symbolName,
                trailingTint: tint,
                text: label.displayString
            )
        case let .word(word):
            return resolveWord(
                word,
                keyword: keyword,
                visualRole: visualRole,
                feedbackClass: feedbackClass
            )
        }
    }

    private static func resolveWord(
        _ word: CombatFeedbackChipWord,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass
    ) -> CombatFeedbackChipPresentation {
        switch word {
        case .dodge:
            iconOnly(trailing: Keyword.dodge.visualStyle)
        case .critical:
            textAndIcon(
                trailing: trailingStyle(
                    keyword: keyword,
                    visualRole: visualRole,
                    feedbackClass: feedbackClass
                ),
                text: "Critical"
            )
        case let .plain(chipKeyword):
            if chipKeyword == .deathsDoor {
                iconOnly(trailing: Keyword.deathsDoor.visualStyle)
            } else {
                textAndIcon(trailing: chipKeyword.visualStyle, text: chipKeyword.rawValue)
            }
        case let .applied(chipKeyword):
            textAndIcon(trailing: chipKeyword.visualStyle, text: chipKeyword.rawValue)
        case let .triggered(chipKeyword):
            textAndIcon(trailing: chipKeyword.visualStyle, text: chipKeyword.rawValue)
        case let .cleanse(chipKeyword):
            dualAction(leading: Keyword.purge.visualStyle, trailing: chipKeyword.visualStyle)
        case let .purge(chipKeyword):
            dualAction(leading: Keyword.purge.visualStyle, trailing: chipKeyword.visualStyle)
        case let .halve(chipKeyword):
            dualAction(leading: .negativeStatus, trailing: chipKeyword.visualStyle)
        case let .status(status):
            resolveStatus(status)
        }
    }

    private static func textAndIcon(
        trailing: Keyword.VisualStyle,
        text: String
    ) -> CombatFeedbackChipPresentation {
        CombatFeedbackChipPresentation(
            leadingSymbolName: nil,
            leadingTint: nil,
            trailingSymbolName: trailing.symbolName,
            trailingTint: trailing,
            text: text
        )
    }

    private static func resolveStatus(
        _ status: CombatFeedbackStatusLabel
    ) -> CombatFeedbackChipPresentation {
        let beneficial = Keyword.VisualStyle.beneficialStatus
        let negative = Keyword.VisualStyle.negativeStatus
        switch status {
        case .avatarOfJustice, .consecrated, .nextHolyStrike:
            return dualAction(leading: beneficial, trailing: Keyword.holy.visualStyle)
        case .manaShield:
            return dualAction(leading: beneficial, trailing: Keyword.mana.visualStyle)
        case .criticalUp, .thorns:
            return dualAction(leading: beneficial, trailing: Keyword.physical.visualStyle)
        case .armorDown:
            return dualAction(leading: negative, trailing: Keyword.armor.visualStyle)
        case .hasted:
            return iconOnly(trailing: beneficial)
        case .marked:
            return iconOnly(trailing: negative)
        }
    }

    private static func iconOnly(trailing: Keyword.VisualStyle) -> CombatFeedbackChipPresentation {
        CombatFeedbackChipPresentation(
            leadingSymbolName: nil,
            leadingTint: nil,
            trailingSymbolName: trailing.symbolName,
            trailingTint: trailing,
            text: nil
        )
    }

    private static func dualAction(
        leading: Keyword.VisualStyle,
        trailing: Keyword.VisualStyle
    ) -> CombatFeedbackChipPresentation {
        CombatFeedbackChipPresentation(
            leadingSymbolName: leading.symbolName,
            leadingTint: leading,
            trailingSymbolName: trailing.symbolName,
            trailingTint: trailing,
            text: nil
        )
    }

    /// Trailing tint for numeric / single-style chips — mirrors legacy `feedbackVisualStyle`.
    private static func trailingStyle(
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass
    ) -> Keyword.VisualStyle {
        switch visualRole {
        case .beneficialStatus:
            return .beneficialStatus
        case .negativeStatus:
            return .negativeStatus
        case .keyword:
            break
        }

        return switch feedbackClass {
        case .heal: .health
        case .resource: keyword == .mana ? .mana : .gold
        case .block: .block
        case .dodge: Keyword.dodge.visualStyle
        case .control: keyword.visualStyle
        case .deathsDoor: Keyword.deathsDoor.visualStyle
        case .directDamage, .critical, .dot, .buff: keyword.visualStyle
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
