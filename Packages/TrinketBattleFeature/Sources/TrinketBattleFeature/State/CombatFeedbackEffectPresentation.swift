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
            displayRule: DisplayRule = .visible
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

    enum StatusChipLayout: Equatable {
        case dualBeneficial(trailing: Keyword)
        case dualNegative(trailing: Keyword)
        case dualBeneficialEventKeyword
        case iconOnlyNegative
    }

    private static let statusChipLayouts: [CombatFeedbackStatusLabel: StatusChipLayout] = [
        .consecrated: .dualBeneficial(trailing: .holy),
        .nextHolyStrike: .dualBeneficial(trailing: .holy),
        .avatar: .dualBeneficial(trailing: .holy),
        .nextStrikeDouble: .dualBeneficial(trailing: .physical),
        .evadeNextHit: .dualBeneficial(trailing: .dodge),
        .manaShield: .dualBeneficial(trailing: .mana),
        .criticalUp: .dualBeneficial(trailing: .physical),
        .thorns: .dualBeneficial(trailing: .physical),
        .ward: .dualBeneficialEventKeyword,
        .blockDown: .dualNegative(trailing: .block),
        .marked: .iconOnlyNegative,
        .hemorrhage: .dualNegative(trailing: .bleed),
    ]

    static func chipPresentation(
        for status: CombatFeedbackStatusLabel,
        keyword: Keyword
    ) -> CombatFeedbackChipPresentation {
        guard let layout = statusChipLayouts[status] else {
            preconditionFailure("Every status label needs chip layout metadata; missing \(status)")
        }
        return layout.chipPresentation(keyword: keyword)
    }

    private static let table: [ActionEvent.EffectOutcome: Descriptor] = [
        .instantHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .leechHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .resourceGain: Descriptor(
            .resource,
            isAdditive: true,
            labelRule: .amount,
            displayRule: .positiveAmountOnly
        ),
        .manaShieldTriggered: Descriptor(.resource, isAdditive: true, labelRule: .amount),
        .cardsDrawn: Descriptor(
            .resource,
            isAdditive: true,
            labelRule: .amount,
            displayRule: .hidden
        ),
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
        .markedConsumed: Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount),
        .leechApplied: Descriptor(.buff, labelRule: .plainKeyword, displayRule: .hidden),
        .shieldHalved: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .blockDown),
        .thornsApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .thorns),
        .markedApplied: Descriptor(.buff, visualRole: .negativeStatus, statusLabel: .marked),
        .criticalChanceApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .criticalUp),
        .manaShieldApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .manaShield),
        .damageKeywordOverrideApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .consecrated),
        .nextHolyStrikeApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .nextHolyStrike),
        .nextStrikeDoubleApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .nextStrikeDouble),
        .evadeNextHitApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .evadeNextHit),
        .wardApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .ward),
        .avatarApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .avatar),
        .recurringDamageApplied: Descriptor(.dot, labelRule: .appliedKeyword),
        .dotAmplified: Descriptor(.dot, labelRule: .triggeredKeyword),
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

private extension CombatFeedbackEffectPresentation.StatusChipLayout {
    func chipPresentation(keyword: Keyword) -> CombatFeedbackChipPresentation {
        switch self {
        case let .dualBeneficial(trailing):
            CombatFeedbackChipPresentation.dualAction(
                leading: .beneficialStatus,
                trailing: .keyword(trailing)
            )
        case let .dualNegative(trailing):
            CombatFeedbackChipPresentation.dualAction(
                leading: .negativeStatus,
                trailing: .keyword(trailing)
            )
        case .dualBeneficialEventKeyword:
            CombatFeedbackChipPresentation.dualAction(
                leading: .beneficialStatus,
                trailing: .keyword(keyword)
            )
        case .iconOnlyNegative:
            CombatFeedbackChipPresentation.iconOnly(trailing: .negativeStatus)
        }
    }
}
