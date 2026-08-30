import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

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
    let text: String?

    static func resolve(
        label: CombatFeedbackChipLabel,
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass,
    ) -> Self {
        switch label {
        case .amount:
            let style = trailingStyle(
                keyword: keyword,
                visualRole: visualRole,
                feedbackClass: feedbackClass,
            )
            return Self(
                leadingStyle: nil,
                trailingStyle: style,
                text: label.displayString,
            )
        case let .word(word):
            return resolveWord(
                word,
                keyword: keyword,
            )
        }
    }

    private static func resolveWord(
        _ word: CombatFeedbackChipWord,
        keyword: Keyword,
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
            dualAction(leading: .keyword(.cleanse), trailing: .keyword(chipKeyword))
        case let .purge(chipKeyword):
            dualAction(leading: .keyword(.purge), trailing: .keyword(chipKeyword))
        case let .status(status):
            resolveStatus(status, keyword: keyword)
        }
    }

    private static func textAndIcon(
        trailing: Style,
        text: String,
    ) -> Self {
        Self(
            leadingStyle: nil,
            trailingStyle: trailing,
            text: text,
        )
    }

    private static func resolveStatus(
        _ status: CombatFeedbackStatusLabel,
        keyword: Keyword,
    ) -> Self {
        CombatFeedbackEffectPresentation.chipPresentation(for: status, keyword: keyword)
    }

    static func iconOnly(trailing: Style) -> Self {
        Self(
            leadingStyle: nil,
            trailingStyle: trailing,
            text: nil,
        )
    }

    static func dualAction(
        leading: Style,
        trailing: Style,
    ) -> Self {
        Self(
            leadingStyle: leading,
            trailingStyle: trailing,
            text: nil,
        )
    }

    private static func trailingStyle(
        keyword: Keyword,
        visualRole: CombatFeedbackVisualRole,
        feedbackClass: CombatFeedbackClass,
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
            feedbackClass: feedbackClass,
        )
    }
}
