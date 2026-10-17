import TrinketContent
import TrinketCore

public struct BattleActionContext: Equatable, Sendable {
    public let actor: Combatant
    public let selectedTarget: Combatant

    public init(actor: Combatant, selectedTarget: Combatant) {
        self.actor = actor
        self.selectedTarget = selectedTarget
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
            if actor.role == .enemy {
                return state.enemy
            }
            let hero = state.hero
            let companion = state.companion
            let heroHealth = state.health(of: hero)
            let companionHealth = state.health(of: companion)
            let heroAlive = heroHealth > 0
            let companionAlive = companionHealth > 0
            if heroAlive && !companionAlive {
                return hero
            }
            if companionAlive && !heroAlive {
                return companion
            }
            if !heroAlive && !companionAlive {
                return hero
            }
            let heroInjured = heroHealth < state.maxHealth(of: hero)
            let companionInjured = companionHealth < state.maxHealth(of: companion)
            if heroInjured && !companionInjured {
                return hero
            }
            if companionInjured && !heroInjured {
                return companion
            }
            return companionHealth < heroHealth ? companion : hero
        case .defeatedAlly:
            let members = allies(in: state)
            return members.reversed().first { state.health(of: $0) <= 0 } ?? members.first ?? actor
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
        var selectedIsInjured = false
        for member in members {
            let health = state.health(of: member)
            guard health > 0 else { continue }
            let injured = health < state.maxHealth(of: member)
            if selected == nil || injured && !selectedIsInjured || injured == selectedIsInjured && health < lowestHealth {
                selected = member
                lowestHealth = health
                selectedIsInjured = injured
            }
        }
        return selected ?? members.first ?? state.hero
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
        return selected ?? members.first ?? state.hero
    }
}
