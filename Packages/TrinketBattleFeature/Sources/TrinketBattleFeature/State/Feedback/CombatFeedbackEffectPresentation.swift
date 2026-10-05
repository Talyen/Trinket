import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackEffectPresentation {
    enum DisplayRule: Equatable {
        case visible
        case positiveAmountOnly
        case hidden
    }

    enum LabelRule: Equatable {
        case none
        case status(CombatFeedbackStatusLabel)
        case amount
        case negatedAmount
        case dodgeWord
        case plainKeyword
        case appliedKeyword
        case triggeredKeyword
        case cleanseKeyword
        case purgeKeyword
        case deathsDoorIcon
    }

    struct Descriptor {
        let feedbackClass: CombatFeedbackClass
        let visualRole: CombatFeedbackVisualRole
        let isAdditive: Bool
        let labelRule: LabelRule
        let displayRule: DisplayRule

        init(
            _ feedbackClass: CombatFeedbackClass,
            visualRole: CombatFeedbackVisualRole = .keyword,
            isAdditive: Bool = false,
            labelRule: LabelRule,
            displayRule: DisplayRule = .visible,
        ) {
            self.feedbackClass = feedbackClass
            self.visualRole = visualRole
            self.isAdditive = isAdditive
            self.labelRule = labelRule
            self.displayRule = displayRule
        }

        func shouldDisplay(amount: Int) -> Bool {
            switch displayRule {
            case .visible:
                true
            case .positiveAmountOnly:
                amount >= 0
            case .hidden:
                false
            }
        }
    }

    static func chipPresentation(
        for status: CombatFeedbackStatusLabel,
        keyword: Keyword,
    ) -> CombatFeedbackChipPresentation {
        switch status {
        case .consecrated, .nextHolyStrike, .avatar:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.holy))
        case .nextStrikeDouble, .criticalUp:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.physical))
        case .kindled:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.burn))
        case .evadeNextHit:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.dodge))
        case .manaShield:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.mana))
        case .thorns:
            CombatFeedbackChipPresentation.dualAction(leading: .beneficialStatus, trailing: .keyword(.thorns))
        case .leech, .ward:
            CombatFeedbackChipPresentation.dualAction(
                leading: .beneficialStatus,
                trailing: .keyword(status == .leech ? .leech : keyword),
            )
        case .amplified:
            CombatFeedbackChipPresentation.dualAction(leading: .negativeStatus, trailing: .keyword(keyword))
        case .blockDown:
            CombatFeedbackChipPresentation.dualAction(leading: .negativeStatus, trailing: .keyword(.block))
        case .marked:
            CombatFeedbackChipPresentation.iconOnly(trailing: .negativeStatus)
        case .hemorrhage:
            CombatFeedbackChipPresentation.dualAction(leading: .negativeStatus, trailing: .keyword(.bleed))
        }
    }

    // swiftlint:disable:next function_body_length - one exhaustive mapping makes new outcomes require a presentation policy at compile time
    static func descriptor(for effectKind: ActionEvent.EffectOutcome) -> Descriptor {
        switch effectKind {
        case .instantHeal, .overheal, .leechHeal:
            Descriptor(.heal, isAdditive: true, labelRule: .amount)
        case .resourceGain:
            Descriptor(.resource, isAdditive: true, labelRule: .amount, displayRule: .positiveAmountOnly)
        case .manaShieldTriggered:
            Descriptor(.resource, isAdditive: true, labelRule: .amount)
        case .cardsDrawn:
            Descriptor(.resource, isAdditive: true, labelRule: .amount, displayRule: .hidden)
        case .partyDamagePreparationApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .amount)
        case .blockSpent:
            Descriptor(.buff, labelRule: .negatedAmount)
        case .blockStripped:
            Descriptor(.control, labelRule: .negatedAmount)
        case .shieldApplied:
            Descriptor(.buff, isAdditive: true, labelRule: .amount)
        case .shieldAbsorbed:
            Descriptor(.block, isAdditive: true, labelRule: .negatedAmount)
        case .dodgeApplied:
            Descriptor(.dodge, labelRule: .dodgeWord)
        case .controlActionSkipped:
            Descriptor(.control, labelRule: .plainKeyword)
        case .controlApplied:
            Descriptor(.control, labelRule: .appliedKeyword, displayRule: .hidden)
        case .controlTriggered:
            Descriptor(.control, labelRule: .triggeredKeyword)
        case .cleanseApplied:
            Descriptor(.buff, labelRule: .cleanseKeyword)
        case .purgeApplied:
            Descriptor(.buff, labelRule: .purgeKeyword)
        case .deathsDoorTriggered, .deathsDoorExpired:
            Descriptor(.deathsDoor, labelRule: .deathsDoorIcon)
        case .thornsTriggered, .hemorrhageTriggered:
            Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount)
        case .markedConsumed:
            Descriptor(.directDamage, labelRule: .none, displayRule: .hidden)
        case .leechApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.leech))
        case .shieldHalved:
            Descriptor(.buff, visualRole: .negativeStatus, labelRule: .status(.blockDown))
        case .thornsApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.thorns))
        case .markedApplied:
            Descriptor(.buff, visualRole: .negativeStatus, labelRule: .status(.marked))
        case .criticalChanceApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.criticalUp))
        case .manaShieldApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.manaShield))
        case .damageKeywordOverrideApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.consecrated))
        case .nextHolyStrikeApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.nextHolyStrike))
        case .nextStrikeDoubleApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.nextStrikeDouble))
        case .nextBurnBonusApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.kindled))
        case .evadeNextHitApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.evadeNextHit))
        case .wardApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.ward))
        case .avatarApplied:
            Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .status(.avatar))
        case .recurringDamageApplied:
            Descriptor(.dot, labelRule: .appliedKeyword)
        case .dotAmplified:
            Descriptor(.buff, visualRole: .negativeStatus, labelRule: .status(.amplified))
        case .hemorrhageApplied:
            Descriptor(.buff, visualRole: .negativeStatus, labelRule: .status(.hemorrhage))
        }
    }
}
