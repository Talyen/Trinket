import Foundation
import TrinketContent
import TrinketCore

public protocol SimulationPlayPolicy: Sendable {
    var id: String { get }
    func preferredPlayableCard(in battle: BattleState) -> BattleCard?
}

/// Prefer lethal damage, then higher ability tiers, then raw direct damage.
/// Stable `id` is recorded in balance-sweep reports.
public struct GreedyHeuristicPolicy: SimulationPlayPolicy {
    public static let id = "greedy-v1"

    public init() {}

    public var id: String {
        Self.id
    }

    public func preferredPlayableCard(in battle: BattleState) -> BattleCard? {
        HeuristicCardScoring.preferredPlayableCard(in: battle, setupAware: false)
    }
}

/// Same lethal/suicide guards as `GreedyHeuristicPolicy`, with extra value for
/// applying missing DoT/control and a smaller bonus for playing into existing DoTs.
public struct SetupAwareHeuristicPolicy: SimulationPlayPolicy {
    public static let id = "setup-v1"

    public init() {}

    public var id: String {
        Self.id
    }

    public func preferredPlayableCard(in battle: BattleState) -> BattleCard? {
        HeuristicCardScoring.preferredPlayableCard(in: battle, setupAware: true)
    }
}

private enum HeuristicCardScoring {
    static func preferredPlayableCard(in battle: BattleState, setupAware: Bool) -> BattleCard? {
        let playable = battle.hand.cards.filter { battle.isCardPlayable($0) }
        return playable.max(by: { lhs, rhs in
            score(lhs, in: battle, setupAware: setupAware) < score(rhs, in: battle, setupAware: setupAware)
        })
    }

    private static func score(_ card: BattleCard, in battle: BattleState, setupAware: Bool) -> Int {
        let ability = card.ability
        let enemyHP = battle.health(of: battle.enemy)
        let ownerCombatant = card.owner == .hero ? battle.hero : battle.companion
        let actorHP = battle.health(of: ownerCombatant)
        let maxHP = max(battle.maxHealth(of: ownerCombatant), 1)
        let hpFraction = Double(actorHP) / Double(maxHP)

        let damage = ability.directDamage
        let selfDamage = ability.damageComponents
            .filter { $0.target == .actor }
            .reduce(0) { $0 + $1.amount }

        if damage > 0, damage >= enemyHP {
            return 10000 + damage
        }
        if selfDamage > 0, selfDamage >= actorHP {
            return -10000
        }

        let selfDamagePenalty = (selfDamage > 0 && hpFraction < 0.5) ? (selfDamage * 10 + 50) : (selfDamage * 2)
        var value = damage - selfDamagePenalty

        if ability.hasLeech {
            value += 5
        }

        let enemyEffects = battle.roster.activeEffects(for: battle.enemy)
        value += effectScore(ability: ability, enemyEffects: enemyEffects, setupAware: setupAware)
        return value
    }

    private static func effectScore(
        ability: Ability,
        enemyEffects: [ActiveEffect],
        setupAware: Bool
    ) -> Int {
        var value = 0
        for targeted in ability.targetedEffects {
            value += effectValue(targeted.effect, enemyEffects: enemyEffects, setupAware: setupAware)
        }
        return value
    }

    private static func effectValue(
        _ effect: Effect,
        enemyEffects: [ActiveEffect],
        setupAware: Bool
    ) -> Int {
        switch effect {
        case let .drawCards(count):
            setupAware ? count * 5 : count * 3
        case let .drawAndPlayCards(count):
            count * 5
        case let .shield(_, amount):
            amount
        case let .instantHeal(_, amount):
            amount
        case let .burn(amount):
            dotScore(amount: amount, keyword: .burn, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .poison(amount):
            dotScore(amount: amount, keyword: .poison, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .bleed(amount):
            dotScore(amount: amount, keyword: .bleed, enemyEffects: enemyEffects, setupAware: setupAware)
        case let .resourceGain(keyword, amount):
            keyword == .mana ? amount * 2 : amount
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
        setupAware: Bool
    ) -> Int {
        guard setupAware else { return amount * 2 }
        let hasDot = enemyEffects.contains { $0.effect.keyword == keyword }
        return hasDot ? amount * 3 : amount * 5
    }
}
