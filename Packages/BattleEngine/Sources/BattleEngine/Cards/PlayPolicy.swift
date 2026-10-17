import TrinketContent
import TrinketCore

public enum PlayPolicy: String, Sendable, CaseIterable {
    case greedy = "greedy-v1"
    case setupAware = "setup-v1"

    public var id: String {
        rawValue
    }

    public func preferredPlayableCard(in battle: BattleState) -> BattleCard? {
        HeuristicCardScoring.preferredPlayableCard(in: battle, setupAware: self == .setupAware)
    }
}

private enum HeuristicCardScoring {
    static func preferredPlayableCard(in battle: BattleState, setupAware: Bool) -> BattleCard? {
        guard !battle.hand.cards.isEmpty else { return nil }
        let enemyEffects = battle.roster.activeEffects(for: battle.enemy)
        var bestCard: BattleCard?
        var bestScore = Int.min
        for card in battle.hand.cards where battle.isCardPlayable(card) {
            if finishesBattle(card, in: battle) {
                return card
            }
            let cardScore = score(
                card, in: battle, setupAware: setupAware,
                enemyEffects: enemyEffects,
            )
            if cardScore > bestScore {
                bestScore = cardScore
                bestCard = card
            }
        }
        return bestCard
    }

    private static func finishesBattle(_ card: BattleCard, in battle: BattleState) -> Bool {
        // Resolve only on a value copy: selection must preserve the live RNG,
        // hand, preparations and recording callback. Reuse combat rules rather
        // than treating printed damage as damage that will reach the enemy.
        var forecast = battle
        forecast.events = []
        guard (try? forecast.playCard(cardID: card.id, rebuildLog: false)) != nil else { return false }
        return forecast.isEnemyDefeated && forecast.roster[card.owner].isAlive
    }

    private static func score(
        _ card: BattleCard,
        in battle: BattleState,
        setupAware: Bool,
        enemyEffects: [ActiveEffect],
    ) -> Int {
        let actor = battle.roster[card.owner].combatant
        let action = BattleActionContext(actor: actor, in: battle)
        let outcomes = BattleAbilityRules.possibleOutcomes(card.ability, action: action, in: battle)
        let branches = outcomes.branches
        let total = branches.reduce(0) { sum, branch in
            SaturatedArithmetic.saturatingAdd(sum, score(
                branch, action: action, in: battle, setupAware: setupAware, enemyEffects: enemyEffects,
            ))
        }
        return SaturatedArithmetic.saturatingAdd(total / max(1, branches.count), outcomes.ability.hasLeech ? 5 : 0)
    }

    private static func score(
        _ branch: AbilityOutcomeBranch,
        action: BattleActionContext,
        in battle: BattleState,
        setupAware: Bool,
        enemyEffects: [ActiveEffect],
    ) -> Int {
        var damage = 0
        var selfDamage = 0
        var effects = 0
        // These are opening-state estimates; the finishing forecast resolves every checkpoint.
        for operation in branch.operations {
            switch operation {
            case let .damage(component):
                guard let amount = BattleDamageRules.amount(component, action: action, in: battle) else { continue }
                if action.target(component.target, in: battle).id == action.actor.id {
                    selfDamage = SaturatedArithmetic.saturatingAdd(selfDamage, amount)
                } else {
                    damage = SaturatedArithmetic.saturatingAdd(damage, amount)
                }
            case let .effect(targeted):
                effects = SaturatedArithmetic.saturatingAdd(
                    effects, effectValue(targeted.effect, enemyEffects: enemyEffects, setupAware: setupAware),
                )
            }
        }
        let lowHealth = HealthThreshold.isBelowHalf(battle.health(of: action.actor), maximum: battle.maxHealth(of: action.actor))
        let penalty = selfDamage > 0 && lowHealth
            ? SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingMul(selfDamage, 10), 50)
            : SaturatedArithmetic.saturatingMul(selfDamage, 2)
        return SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingSub(damage, penalty), effects)
    }

    private static func effectValue(
        _ effect: Effect,
        enemyEffects: [ActiveEffect],
        setupAware: Bool,
    ) -> Int {
        switch effect {
        case let .drawCards(count):
            SaturatedArithmetic.saturatingMul(count, setupAware ? 5 : 3)
        case let .drawAndPlayCards(count):
            SaturatedArithmetic.saturatingMul(count, 5)
        case let .shield(_, amount):
            amount
        case let .blessedAegis(block, _):
            SaturatedArithmetic.saturatingAdd(SaturatedArithmetic.saturatingMul(block, 2), 4)
        case let .instantHeal(_, amount):
            amount
        case let .burn(amount):
            dotScore(amount: amount, keyword: .burn, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .poison(amount):
            dotScore(amount: amount, keyword: .poison, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .bleed(amount):
            dotScore(amount: amount, keyword: .bleed, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .resourceGain(keyword, amount):
            keyword == .mana ? SaturatedArithmetic.saturatingMul(amount, 2) : amount
        case .convertManaToBlock:
            4
        case .controlMeter:
            if setupAware {
                enemyEffects.contains(where: \.effect.isActionSkipPending) ? 4 : 12
            } else {
                2
            }
        default:
            2
        }
    }

    private static func dotScore(
        amount: Int,
        keyword: Keyword,
        enemyEffects: [ActiveEffect],
        setupAware: Bool,
    ) -> Int {
        guard setupAware else { return SaturatedArithmetic.saturatingMul(amount, 2) }
        let hasDot = enemyEffects.contains { $0.effect.keyword == keyword }
        return SaturatedArithmetic.saturatingMul(amount, hasDot ? 3 : 5)
    }
}
