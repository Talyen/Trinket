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

    enum LabelRule {
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
        let statusLabel: CombatFeedbackStatusLabel?
        let labelRule: LabelRule?
        let displayRule: DisplayRule

        init(
            _ feedbackClass: CombatFeedbackClass,
            visualRole: CombatFeedbackVisualRole = .keyword,
            isAdditive: Bool = false,
            statusLabel: CombatFeedbackStatusLabel? = nil,
            labelRule: LabelRule? = nil,
            displayRule: DisplayRule = .visible,
        ) {
            self.feedbackClass = feedbackClass
            self.visualRole = visualRole
            self.isAdditive = isAdditive
            self.statusLabel = statusLabel
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

    private static let table: [ActionEvent.EffectOutcome: Descriptor] = [
        .instantHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .overheal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .leechHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .resourceGain: Descriptor(
            .resource,
            isAdditive: true,
            labelRule: .amount,
            displayRule: .positiveAmountOnly,
        ),
        .manaShieldTriggered: Descriptor(.resource, isAdditive: true, labelRule: .amount),
        .cardsDrawn: Descriptor(
            .resource,
            isAdditive: true,
            labelRule: .amount,
            displayRule: .hidden,
        ),
        .partyDamagePreparationApplied: Descriptor(.buff, visualRole: .beneficialStatus, labelRule: .amount),
        .blockSpent: Descriptor(.buff, labelRule: .negatedAmount),
        .blockStripped: Descriptor(.block, labelRule: .negatedAmount),
        .shieldApplied: Descriptor(.buff, isAdditive: true, labelRule: .amount),
        .shieldAbsorbed: Descriptor(.block, isAdditive: true, labelRule: .negatedAmount),
        .dodgeApplied: Descriptor(.dodge, labelRule: .dodgeWord),
        .controlActionSkipped: Descriptor(.control, labelRule: .plainKeyword),
        .controlApplied: Descriptor(.control, labelRule: .appliedKeyword, displayRule: .hidden),
        .controlTriggered: Descriptor(.control, labelRule: .triggeredKeyword),
        .cleanseApplied: Descriptor(.buff, labelRule: .cleanseKeyword),
        .purgeApplied: Descriptor(.buff, labelRule: .purgeKeyword),
        .deathsDoorTriggered: Descriptor(.deathsDoor, labelRule: .deathsDoorIcon),
        .deathsDoorExpired: Descriptor(.deathsDoor, labelRule: .deathsDoorIcon),
        .thornsTriggered: Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount),
        .markedConsumed: Descriptor(.directDamage, displayRule: .hidden),
        .leechApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .leech),
        .shieldHalved: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .blockDown),
        .thornsApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .thorns),
        .markedApplied: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .marked),
        .criticalChanceApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .criticalUp),
        .manaShieldApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .manaShield),
        .damageKeywordOverrideApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .consecrated),
        .nextHolyStrikeApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .nextHolyStrike),
        .nextStrikeDoubleApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .nextStrikeDouble),
        .nextBurnBonusApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .kindled),
        .evadeNextHitApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .evadeNextHit),
        .wardApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .ward),
        .avatarApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .avatar),
        .recurringDamageApplied: Descriptor(.dot, labelRule: .appliedKeyword),
        .dotAmplified: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .amplified),
        .hemorrhageApplied: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .hemorrhage),
        .hemorrhageTriggered: Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount),
    ]

    static func descriptor(for effectKind: ActionEvent.EffectOutcome) -> Descriptor {
        guard let descriptor = table[effectKind] else {
            preconditionFailure("Every EffectOutcome needs a presentation entry; missing \(effectKind)")
        }
        return descriptor
    }
}
