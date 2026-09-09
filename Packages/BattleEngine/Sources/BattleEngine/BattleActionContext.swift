import TrinketContent
import TrinketCore

public struct BattleActionContext: Equatable, Sendable {
    public let actor: Combatant
    public let selectedTarget: Combatant

    public init(actor: Combatant, selectedTarget: Combatant) {
        self.actor = actor
        self.selectedTarget = selectedTarget
    }

    public init(actor: Combatant, in state: BattleState) {
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
            selectedTarget
        case .actor:
            actor
        case .hero:
            state.hero
        case .companion:
            state.companion
        case .lowestHealthAlly:
            Self.lowestHealth(in: allies(in: state), state: state)
        case .defeatedAlly:
            allies(in: state).reversed().first { state.health(of: $0) <= 0 } ?? allies(in: state)[0]
        }
    }

    func canContinue(in state: BattleState) -> Bool {
        state.health(of: actor) > 0
    }

    static func lowestHealth(in members: [Combatant], state: BattleState) -> Combatant {
        members.filter { state.health(of: $0) > 0 }
            .min { state.health(of: $0) < state.health(of: $1) } ?? members[0]
    }

    static func mostDebuffed(in members: [Combatant], state: BattleState) -> Combatant {
        members.filter { state.health(of: $0) > 0 }.sorted {
            let left = state.activeEffects(of: $0).count(where: \.effect.isRemovableDebuff)
            let right = state.activeEffects(of: $1).count(where: \.effect.isRemovableDebuff)
            if left == right {
                return state.health(of: $0) < state.health(of: $1)
            }
            return left > right
        }.first ?? members[0]
    }
}
