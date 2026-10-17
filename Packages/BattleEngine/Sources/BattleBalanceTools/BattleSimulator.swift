import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public struct BattleSimResult: Equatable, Codable, Sendable {
    public var outcome: BattleSimulationOutcome
    public var rounds: Int
    public var actions: Int
    public var timedOut: Bool
    public var partyHPRemainingFraction: Double
    public var enemyHPRemainingFraction: Double

    public var isVictory: Bool {
        !timedOut && outcome == .victory
    }

    public var isDecided: Bool {
        !timedOut
    }
}

public enum BattleSimulator {
    public static let defaultMaxRounds = 100
    public static let defaultMaxActions = 500

    public static func run(
        matchup: ConfiguredSimulationMatchup,
        policy: PlayPolicy,
        maxRounds: Int = defaultMaxRounds,
        maxActions: Int = defaultMaxActions,
        appliesFightPacing: Bool = true,
        tracksEvents: Bool = false,
    ) -> BattleSimResult {
        var battle = makeBattle(matchup: matchup, appliesFightPacing: appliesFightPacing, tracksEvents: tracksEvents)
        return run(battle: &battle, policy: policy, maxRounds: maxRounds, maxActions: maxActions)
    }

    static func makeBattle(
        matchup: ConfiguredSimulationMatchup,
        appliesFightPacing: Bool = true,
        tracksEvents: Bool = false,
    ) -> BattleState {
        BattleState(
            hero: matchup.hero,
            companion: matchup.companion,
            enemy: matchup.enemy,
            heroModifiers: matchup.heroModifiers,
            companionModifiers: matchup.companionModifiers,
            enemyModifiers: matchup.enemyModifiers,
            enemyFaction: matchup.enemyFaction,
            rngSeed: matchup.context.seed,
            tracksLog: false,
            tracksEvents: tracksEvents,
            appliesFightPacing: appliesFightPacing,
        )
    }

    public static func run(
        battle: inout BattleState,
        policy: PlayPolicy,
        maxRounds: Int = defaultMaxRounds,
        maxActions: Int = defaultMaxActions,
    ) -> BattleSimResult {
        var actions = 0
        var timedOut = false

        while !battle.isBattleOver {
            if battle.turnCount >= maxRounds || actions >= maxActions {
                timedOut = true
                break
            }
            actions += 1
            if let card = policy.preferredPlayableCard(in: battle) {
                do {
                    _ = try battle.playCard(cardID: card.id, rebuildLog: false)
                } catch {
                    _ = battle.endTurn(rebuildLog: false)
                }
            } else if battle.phase == .playerTurn {
                _ = battle.endTurn(rebuildLog: false)
            }
        }

        let outcome = BattleSimulationOutcome.resolve(
            isPartyDefeated: battle.isPartyDefeated,
            isEnemyDefeated: battle.isEnemyDefeated,
        ) ?? .defeat

        return BattleSimResult(
            outcome: outcome,
            rounds: battle.turnCount,
            actions: actions,
            timedOut: timedOut,
            partyHPRemainingFraction: partyHPFraction(in: battle),
            enemyHPRemainingFraction: enemyHPFraction(in: battle),
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
        combatantHPFraction(battle.enemy, in: battle)
    }

    private static func combatantHPFraction(_ combatant: Combatant, in battle: BattleState) -> Double {
        let maxHP = Double(max(battle.maxHealth(of: combatant), 1))
        return Double(max(battle.health(of: combatant), 0)) / maxHP
    }
}
