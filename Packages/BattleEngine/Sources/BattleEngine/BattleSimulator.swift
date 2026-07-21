import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct BattleSimResult: Equatable, Sendable {
    public var outcome: BattleSimulationOutcome
    public var rounds: Int
    public var actions: Int
    public var timedOut: Bool
    public var partyHPRemainingFraction: Double
    public var enemyHPRemainingFraction: Double

    public init(
        outcome: BattleSimulationOutcome,
        rounds: Int,
        actions: Int,
        timedOut: Bool,
        partyHPRemainingFraction: Double,
        enemyHPRemainingFraction: Double
    ) {
        self.outcome = outcome
        self.rounds = rounds
        self.actions = actions
        self.timedOut = timedOut
        self.partyHPRemainingFraction = partyHPRemainingFraction
        self.enemyHPRemainingFraction = enemyHPRemainingFraction
    }

    public var isVictory: Bool {
        outcome == .victory
    }
}

/// Headless driver for bulk balance simulation. Avoids UI / log / event retention.
public enum BattleSimulator {
    public static let defaultMaxRounds = 100
    public static let defaultMaxActions = 500

    public static func run(
        matchup: ConfiguredSimulationMatchup,
        policy: GreedyHeuristicPolicy,
        maxRounds: Int = defaultMaxRounds,
        maxActions: Int = defaultMaxActions
    ) -> BattleSimResult {
        var battle = BattleState(
            hero: matchup.hero,
            companion: matchup.companion,
            enemy: matchup.enemy,
            heroModifiers: matchup.heroModifiers,
            companionModifiers: matchup.companionModifiers,
            enemyModifiers: matchup.enemyModifiers,
            rngSeed: matchup.context.seed,
            tracksLog: false,
            tracksEvents: false
        )
        return run(battle: &battle, policy: policy, maxRounds: maxRounds, maxActions: maxActions)
    }

    public static func run(
        battle: inout BattleState,
        policy: GreedyHeuristicPolicy,
        maxRounds: Int = defaultMaxRounds,
        maxActions: Int = defaultMaxActions
    ) -> BattleSimResult {
        var actions = 0
        var timedOut = false

        while !battle.isBattleOver {
            if battle.turnCount >= maxRounds || actions >= maxActions {
                timedOut = true
                break
            }
            actions += 1
            switch policy.nextAction(in: battle) {
            case let .playCard(cardID):
                do {
                    _ = try battle.playCard(cardID: cardID, rebuildLog: false)
                } catch {
                    // Illegal choice — end turn to make progress rather than spin.
                    _ = battle.endTurn(rebuildLog: false)
                }
            case .endTurn:
                guard battle.phase == .playerTurn else { break }
                _ = battle.endTurn(rebuildLog: false)
            }
        }

        let outcome = BattleSimulationOutcome.resolve(
            isPartyDefeated: battle.isPartyDefeated,
            isEnemyDefeated: battle.isEnemyDefeated
        ) ?? (timedOut ? .defeat : .defeat)

        return BattleSimResult(
            outcome: outcome,
            rounds: battle.turnCount,
            actions: actions,
            timedOut: timedOut,
            partyHPRemainingFraction: partyHPFraction(in: battle),
            enemyHPRemainingFraction: enemyHPFraction(in: battle)
        )
    }

    private static func partyHPFraction(in battle: BattleState) -> Double {
        let heroMax = Double(max(battle.maxHealth(of: battle.hero), 1))
        let companionMax = Double(max(battle.maxHealth(of: battle.companion), 1))
        let heroHP = Double(max(battle.health(of: battle.hero), 0))
        let companionHP = Double(max(battle.health(of: battle.companion), 0))
        return (heroHP + companionHP) / (heroMax + companionMax)
    }

    private static func enemyHPFraction(in battle: BattleState) -> Double {
        let maxHP = Double(max(battle.maxHealth(of: battle.enemy), 1))
        return Double(max(battle.health(of: battle.enemy), 0)) / maxHP
    }
}
