import Foundation
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
        let playable = battle.hand.cards.filter { battle.isCardPlayable($0) }
        guard !playable.isEmpty else { return nil }
        var bestCard: BattleCard?
        var bestScore = Int.min
        for card in playable {
            let cardScore = score(card, in: battle, setupAware: setupAware)
            if cardScore > bestScore {
                bestScore = cardScore
                bestCard = card
            }
        }
        return bestCard
    }

    private static func score(_ card: BattleCard, in battle: BattleState, setupAware: Bool) -> Int {
        let ability = card.ability
        let enemyHP = battle.health(of: battle.enemy)
        let ownerCombatant = card.owner == .hero ? battle.hero : battle.companion
        let actorHP = battle.health(of: ownerCombatant)
        let maxHP = max(battle.maxHealth(of: ownerCombatant), 1)
        let hpFraction = Double(actorHP) / Double(maxHP)

        let damage = ability.directDamage
        let selfDamage = ability.damageComponents.reduce(0) { total, component in
            component.target == .actor ? total + component.amount : total
        }

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
        if let branches = ability.outcomeBranches, !branches.isEmpty {
            value += branchScore(branches: branches, enemyEffects: enemyEffects, setupAware: setupAware)
        }
        return value
    }

    private static func branchScore(
        branches: [AbilityOutcomeBranch],
        enemyEffects: [ActiveEffect],
        setupAware: Bool,
    ) -> Int {
        var total = 0
        for branch in branches {
            let branchDamage = branch.damageComponents.reduce(0) { sum, comp in
                comp.target == .actor ? sum : sum + comp.amount
            }
            var branchEffects = 0
            for targeted in branch.targetedEffects {
                branchEffects += effectValue(targeted.effect, enemyEffects: enemyEffects, setupAware: setupAware)
            }
            total += branchDamage + branchEffects
        }
        return total / branches.count
    }

    private static func effectScore(
        ability: Ability,
        enemyEffects: [ActiveEffect],
        setupAware: Bool,
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
        setupAware: Bool,
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
        setupAware: Bool,
    ) -> Int {
        guard setupAware else { return amount * 2 }
        let hasDot = enemyEffects.contains { $0.effect.keyword == keyword }
        return hasDot ? amount * 3 : amount * 5
    }
}
