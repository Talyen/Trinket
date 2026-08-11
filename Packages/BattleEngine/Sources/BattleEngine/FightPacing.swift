import Foundation
import TrinketContent
import TrinketCore

/// Hidden fight pacing: banded comeback and progress-based clock multipliers.
package enum FightPacing {
    package enum Side: Equatable, Sendable {
        case party
        case enemy
    }

    package struct Config: Equatable, Sendable {
        var evenThreshold: Double
        var maxDelta: Double
        var comebackMin: Double
        var comebackMax: Double
        var scheduleThreshold: Double
        var gapFullScale: Double
        var clockMin: Double
        var clockMax: Double
        var targetDuration: Double
        var maxRounds: Int
        var burnFractionAtTarget: Double
        var backstopSpan: Double

        static let trash = Self(
            evenThreshold: 0.10,
            maxDelta: 0.50,
            comebackMin: 0.10,
            comebackMax: 0.20,
            scheduleThreshold: 0.03,
            gapFullScale: 0.10,
            clockMin: 0.10,
            clockMax: 0.20,
            targetDuration: 7.5,
            maxRounds: 10,
            burnFractionAtTarget: 0.50,
            backstopSpan: 4
        )

        static let boss = Self(
            evenThreshold: 0.10,
            maxDelta: 0.50,
            comebackMin: 0.10,
            comebackMax: 0.20,
            scheduleThreshold: 0.03,
            gapFullScale: 0.10,
            clockMin: 0.10,
            clockMax: 0.20,
            targetDuration: 15.0,
            maxRounds: 20,
            burnFractionAtTarget: 0.50,
            backstopSpan: 4
        )
    }

    package struct PoolMetrics: Equatable, Sendable {
        var partyFraction: Double
        var enemyFraction: Double
        var actualBurnFraction: Double
    }

    package static func config(isBoss: Bool) -> Config {
        isBoss ? .boss : .trash
    }

    package static func isBossEnemy(in context: BattleState) -> Bool {
        GameContent.enemy(matching: context.enemy.id)?.isBoss == true
    }

    package static func side(for sourceActorID: String, in context: BattleState) -> Side? {
        guard let runtime = context.roster.combatant(for: sourceActorID) else { return nil }
        switch runtime.combatant.role {
        case .hero, .companion: return .party
        case .enemy: return .enemy
        }
    }

    package static func poolMetrics(in context: BattleState) -> PoolMetrics {
        let partyMax = max(
            1,
            context.roster.maxHealth(for: context.hero) + context.roster.maxHealth(for: context.companion)
        )
        let partyCurrent = max(
            0,
            context.roster.health(for: context.hero) + context.roster.health(for: context.companion)
        )
        let enemyMax = max(1, context.roster.maxHealth(for: context.enemy))
        let enemyCurrent = max(0, context.roster.health(for: context.enemy))
        let totalMax = partyMax + enemyMax
        let totalCurrent = partyCurrent + enemyCurrent
        return PoolMetrics(
            partyFraction: Double(partyCurrent) / Double(partyMax),
            enemyFraction: Double(enemyCurrent) / Double(enemyMax),
            actualBurnFraction: Double(totalMax - totalCurrent) / Double(totalMax)
        )
    }

    package static func multiplier(side: Side, isBoss: Bool, in context: BattleState) -> Double {
        clockMultiplier(isBoss: isBoss, in: context) * comebackMultiplier(side: side, isBoss: isBoss, in: context)
    }

    package static func comebackMultiplier(side: Side, isBoss: Bool, in context: BattleState) -> Double {
        let pacingConfig = Self.config(isBoss: isBoss)
        let metrics = poolMetrics(in: context)
        let hpDelta = metrics.partyFraction - metrics.enemyFraction
        let absDelta = abs(hpDelta)
        guard absDelta >= pacingConfig.evenThreshold else { return 1.0 }

        let partyLosing = hpDelta < 0
        let applies = (side == .party && partyLosing) || (side == .enemy && !partyLosing)
        guard applies else { return 1.0 }

        let span = max(0.000_1, pacingConfig.maxDelta - pacingConfig.evenThreshold)
        let severity = min(1, (absDelta - pacingConfig.evenThreshold) / span)
        let bonus = bandedBonus(
            severity: severity,
            min: pacingConfig.comebackMin,
            max: pacingConfig.comebackMax
        )
        return 1 + bonus
    }

    package static func clockMultiplier(isBoss: Bool, in context: BattleState) -> Double {
        let pacingConfig = Self.config(isBoss: isBoss)
        let scheduleBonus = scheduleClockBonus(in: context, config: pacingConfig)
        let backstopBonus = turnBackstopBonus(in: context, config: pacingConfig)
        return 1 + max(scheduleBonus, backstopBonus)
    }

    package static func scheduleClockBonus(in context: BattleState, config: Config) -> Double {
        let metrics = poolMetrics(in: context)
        let turn = max(0, context.turnCount)
        let normalizedTurn = turn > 0
            ? min(1, Double(turn) / config.targetDuration)
            : 0
        let expectedBurn = config.burnFractionAtTarget * smoothstep(normalizedTurn)
        let scheduleGap = expectedBurn - metrics.actualBurnFraction
        guard scheduleGap >= config.scheduleThreshold else { return 0 }

        let span = max(0.000_1, config.gapFullScale)
        let severity = min(1, (scheduleGap - config.scheduleThreshold) / span)
        return bandedBonus(severity: severity, min: config.clockMin, max: config.clockMax)
    }

    package static func turnBackstopBonus(in context: BattleState, config: Config) -> Double {
        let turnOverrun = max(0, context.turnCount - config.maxRounds)
        guard turnOverrun > 0 else { return 0 }
        let severity = smoothstep(min(1, Double(turnOverrun) / config.backstopSpan))
        return bandedBonus(severity: severity, min: config.clockMin, max: config.clockMax)
    }

    private static func bandedBonus(severity: Double, min minBonus: Double, max maxBonus: Double) -> Double {
        minBonus + (maxBonus - minBonus) * min(1, max(0, severity))
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}
