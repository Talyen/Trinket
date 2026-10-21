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
            return Self.lowestHealthAlly(in: state)
        case .defeatedAlly:
            if actor.role == .enemy {
                return state.enemy
            }
            if !state.roster.companion.isAlive {
                return state.companion
            }
            if !state.roster.hero.isAlive {
                return state.hero
            }
            return actor.id == state.hero.id ? state.companion : state.hero
        case .eachAlly:
            return actor.role == .enemy ? state.enemy : state.hero
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

    static func lowestHealthAlly(in state: BattleState) -> Combatant {
        let hero = state.roster.hero
        let companion = state.roster.companion
        guard companion.isAlive else { return hero.combatant }
        guard hero.isAlive else { return companion.combatant }
        let heroInjured = hero.currentHealth < hero.maxHealth
        let companionInjured = companion.currentHealth < companion.maxHealth
        if heroInjured != companionInjured {
            return heroInjured ? hero.combatant : companion.combatant
        }
        return companion.currentHealth < hero.currentHealth ? companion.combatant : hero.combatant
    }

    func hasLivingAlly(in state: BattleState, where matches: (CombatantRuntime) -> Bool) -> Bool {
        if actor.role == .enemy {
            return state.roster.enemy.isAlive && matches(state.roster.enemy)
        }
        return state.roster.hero.isAlive && matches(state.roster.hero)
            || state.roster.companion.isAlive && matches(state.roster.companion)
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
