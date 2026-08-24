import BattleEngine
import Foundation
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Single source of truth mapping each engine effect outcome to its combat
/// feedback presentation. Adding an `EffectOutcome` forces an entry here; the
/// presenter classification, visual role, additive aggregation, status label,
/// and chip label rule all read from this table instead of parallel switches.
/// Table completeness is enforced by `CombatFeedbackEffectPresentationTests`.
enum CombatFeedbackEffectPresentation {
    /// How an event's chip label is derived. `nil` means the chip renders as a
    /// status icon driven by `statusLabel`.
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
        /// Same-kind events merge their amounts within one action batch.
        let isAdditive: Bool
        let statusLabel: CombatFeedbackStatusLabel?
        let labelRule: LabelRule?

        init(
            _ feedbackClass: CombatFeedbackClass,
            visualRole: CombatFeedbackVisualRole = .keyword,
            isAdditive: Bool = false,
            statusLabel: CombatFeedbackStatusLabel? = nil,
            labelRule: LabelRule? = nil
        ) {
            self.feedbackClass = feedbackClass
            self.visualRole = visualRole
            self.isAdditive = isAdditive
            self.statusLabel = statusLabel
            self.labelRule = labelRule
        }
    }

    private static let table: [ActionEvent.EffectOutcome: Descriptor] = [
        .instantHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .leechHeal: Descriptor(.heal, isAdditive: true, labelRule: .amount),
        .resourceGain: Descriptor(.resource, isAdditive: true, labelRule: .amount),
        .manaShieldTriggered: Descriptor(.resource, isAdditive: true, labelRule: .amount),
        .cardsDrawn: Descriptor(.resource, isAdditive: true, labelRule: .amount),
        .shieldApplied: Descriptor(.buff, isAdditive: true, labelRule: .amount),
        .shieldAbsorbed: Descriptor(.block, isAdditive: true, labelRule: .negatedAmount),
        .dodgeApplied: Descriptor(.dodge, labelRule: .dodgeWord),
        .controlActionSkipped: Descriptor(.control, labelRule: .plainKeyword),
        // Filtered before display (control noise); classified for completeness.
        .controlApplied: Descriptor(.control, labelRule: .appliedKeyword),
        .controlTriggered: Descriptor(.control, labelRule: .triggeredKeyword),
        .cleanseApplied: Descriptor(.buff, labelRule: .cleanseKeyword),
        .purgeApplied: Descriptor(.buff, labelRule: .purgeKeyword),
        .deathsDoorTriggered: Descriptor(.deathsDoor, labelRule: .deathsDoorIcon),
        .deathsDoorExpired: Descriptor(.deathsDoor, labelRule: .deathsDoorIcon),
        .thornsTriggered: Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount),
        .markedConsumed: Descriptor(.directDamage, isAdditive: true, labelRule: .negatedAmount),
        .leechApplied: Descriptor(.buff, visualRole: .beneficialStatus, statusLabel: .leech),
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
    ]

    static func descriptor(for effectKind: ActionEvent.EffectOutcome) -> Descriptor {
        guard let descriptor = table[effectKind] else {
            preconditionFailure("Every EffectOutcome needs a presentation entry; missing \(effectKind)")
        }
        return descriptor
    }
}
