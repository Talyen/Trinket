import TrinketContent
import TrinketCore

public struct BattleActionContext: Equatable, Sendable {
    private final class Participants: Equatable, Sendable {
        let actor: Combatant
        let selectedTarget: Combatant

        init(actor: Combatant, selectedTarget: Combatant) {
            self.actor = actor
            self.selectedTarget = selectedTarget
        }

        static func == (lhs: Participants, rhs: Participants) -> Bool {
            lhs === rhs || (lhs.actor == rhs.actor && lhs.selectedTarget == rhs.selectedTarget)
        }
    }

    private let participants: Participants

    public var actor: Combatant {
        participants.actor
    }

    public var selectedTarget: Combatant {
        participants.selectedTarget
    }

    public init(actor: Combatant, selectedTarget: Combatant) {
        participants = Participants(actor: actor, selectedTarget: selectedTarget)
    }

    public init(actor: Combatant, in state: borrowing BattleState) {
        self.init(actor: actor, selectedTarget: actor.role == .enemy ? state.talentAdjustedEnemyTarget : state.enemy)
    }

    public func allies(in state: BattleState) -> [Combatant] {
        actor.role == .enemy ? [state.enemy] : [state.hero, state.companion]
    }

    public func opponents(in state: BattleState) -> [Combatant] {
        actor.role == .enemy ? [state.hero, state.companion] : [state.enemy]
    }

    public func target(_ target: EffectTarget, in state: BattleState) -> Combatant {
        switch target {
        case .abilityTarget, .enemy:
            return selectedTarget
        case .actor:
            return actor
        case .hero:
            return state.hero
        case .companion:
            return state.companion
        case .lowestHealthAlly:
            return Self.lowestHealth(in: allies(in: state), state: state)
        case .defeatedAlly:
            let members = allies(in: state)
            return members.reversed().first { state.health(of: $0) <= 0 } ?? members[0]
        case .eachAlly:
            return targets(target, in: state).first ?? actor
        }
    }

    public func targets(_ target: EffectTarget, in state: BattleState) -> [Combatant] {
        switch target {
        case .eachAlly:
            allies(in: state)
        default:
            [self.target(target, in: state)]
        }
    }

    func canContinue(in state: borrowing BattleState) -> Bool {
        state.health(of: actor) > 0
    }

    static func lowestHealth(in members: [Combatant], state: BattleState) -> Combatant {
        var selected: Combatant?
        var lowestHealth = Int.max
        for member in members {
            let health = state.health(of: member)
            guard health > 0 else { continue }
            if selected == nil || health < lowestHealth {
                selected = member
                lowestHealth = health
            }
        }
        return selected ?? members[0]
    }

    static func mostDebuffed(in members: [Combatant], state: BattleState) -> Combatant {
        var selected: Combatant?
        var mostDebuffs = 0
        var lowestHealth = Int.max
        for member in members {
            let health = state.health(of: member)
            guard health > 0 else { continue }
            let debuffs = state.activeEffects(of: member).count(where: \.effect.isRemovableDebuff)
            // Keep arrival order when both debuff count and Health tie.
            if selected == nil || debuffs > mostDebuffs || debuffs == mostDebuffs && health < lowestHealth {
                selected = member
                mostDebuffs = debuffs
                lowestHealth = health
            }
        }
        return selected ?? members[0]
    }
}
