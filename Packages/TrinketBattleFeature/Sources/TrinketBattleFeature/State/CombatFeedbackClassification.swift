import BattleEngine
import TrinketDesignSystem
import TrinketFeatureSupport

enum CombatFeedbackClassification {
    static func displayPriority(for feedbackClass: CombatFeedbackClass) -> Int {
        switch feedbackClass {
        case .critical: 0
        case .deathsDoor: 1
        case .directDamage: 2
        case .heal: 3
        case .block, .dodge, .control: 4
        case .dot: 5
        case .buff, .resource: 6
        }
    }

    static func classify(_ event: ActionEvent) -> CombatFeedbackClass {
        switch event.kind {
        case .status:
            return .dot
        case .ability, .abilityDamage:
            return .directDamage
        case .milestone:
            return .buff
        case .effect:
            break
        }

        return switch event.effectKind {
        case .instantHeal, .leechHeal:
            .heal
        case .resourceGain, .manaShieldTriggered, .cardsDrawn:
            .resource
        case .shieldAbsorbed:
            .block
        case .dodgeApplied:
            .dodge
        case .controlActionSkipped, .controlApplied, .controlTriggered:
            .control
        case .deathsDoorTriggered, .deathsDoorExpired:
            .deathsDoor
        case .thornsTriggered, .markedConsumed:
            .directDamage
        default:
            .buff
        }
    }

    static func reactionKind(for feedbackClass: CombatFeedbackClass) -> CombatantHitReactionKind {
        switch feedbackClass {
        case .directDamage:
            .damage
        case .dot:
            .none
        case .critical:
            .critical
        case .block:
            .block
        case .heal:
            .heal
        case .dodge:
            .dodge
        case .control, .buff, .resource, .deathsDoor:
            .none
        }
    }
}
