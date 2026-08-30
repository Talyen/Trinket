import Testing
@testable import TrinketCore

struct EnemyPowerCurveTests {
    @Test func `stat anchors match design targets`() throws {
        try #expect(abs(EnemyPowerCurve.stats(level: 1, isBoss: false) - 4.20) < 0.001)
        try #expect(abs(EnemyPowerCurve.stats(level: 20, isBoss: false) - 5.59) < 0.001)
        try #expect(abs(EnemyPowerCurve.stats(level: 40, isBoss: false) - 9.30) < 0.001)
        try #expect(abs(EnemyPowerCurve.stats(level: 1, isBoss: true) - 5.20) < 0.001)
        try #expect(abs(EnemyPowerCurve.stats(level: 20, isBoss: true) - 10.77) < 0.001)
        try #expect(abs(EnemyPowerCurve.stats(level: 40, isBoss: true) - 24.50) < 0.001)
    }

    @Test func `boss health stays at its design multiplier at every level`() throws {
        try #expect(abs(EnemyPowerCurve.bossHealthMultiplier - 1.75) < 0.001)
        for level in 1 ... 40 {
            let normal = EnemyPowerCurve.health(level: level, isBoss: false)
            let boss = EnemyPowerCurve.health(level: level, isBoss: true)
            try #expect(abs(boss / normal - EnemyPowerCurve.bossHealthMultiplier) < 0.0001)
        }
    }

    @Test func `trash health matches trash stats`() throws {
        try #expect(EnemyPowerCurve.health(level: 1, isBoss: false) == EnemyPowerCurve.stats(level: 1, isBoss: false))
        try #expect(EnemyPowerCurve.health(level: 20, isBoss: false) == EnemyPowerCurve.stats(level: 20, isBoss: false))
        try #expect(EnemyPowerCurve.health(level: 40, isBoss: false) == EnemyPowerCurve.stats(level: 40, isBoss: false))
    }

    @Test func `curve is continuous across bracket boundaries`() throws {
        let beforeTwenty = EnemyPowerCurve.stats(level: 19, isBoss: false)
        let atTwenty = EnemyPowerCurve.stats(level: 20, isBoss: false)
        let afterTwenty = EnemyPowerCurve.stats(level: 21, isBoss: false)
        try #expect(EnemyPowerCurve.stats(level: 1, isBoss: false) < atTwenty)
        try #expect(EnemyPowerCurve.stats(level: 1, isBoss: true) < EnemyPowerCurve.stats(level: 20, isBoss: true))
        try #expect(beforeTwenty < atTwenty)
        try #expect(atTwenty <= afterTwenty)
        try #expect(abs(atTwenty - afterTwenty) < 0.1)

        let healthBefore = EnemyPowerCurve.health(level: 19, isBoss: true)
        let healthAt = EnemyPowerCurve.health(level: 20, isBoss: true)
        let healthAfter = EnemyPowerCurve.health(level: 21, isBoss: true)
        try #expect(healthBefore < healthAt)
        try #expect(healthAt <= healthAfter)
        try #expect(abs(healthAt - healthAfter) < 0.1)
    }
}
