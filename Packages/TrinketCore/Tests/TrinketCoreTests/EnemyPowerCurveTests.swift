import Testing
@testable import TrinketCore

struct EnemyPowerCurveTests {
    @Test func anchorsMatchDesignTargets() throws {
        try #expect(abs(EnemyPowerCurve.power(level: 1, isBoss: false) - 2.10) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 20, isBoss: false) - 2.65) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 40, isBoss: false) - 3.10) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 1, isBoss: true) - 3.22) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 20, isBoss: true) - 5.10) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 40, isBoss: true) - 6.30) < 0.001)
    }

    @Test func curveIsContinuousAcrossBracketBoundaries() throws {
        let beforeTwenty = EnemyPowerCurve.power(level: 19, isBoss: false)
        let atTwenty = EnemyPowerCurve.power(level: 20, isBoss: false)
        let afterTwenty = EnemyPowerCurve.power(level: 21, isBoss: false)
        try #expect(beforeTwenty < atTwenty)
        try #expect(atTwenty <= afterTwenty)
        try #expect(abs(atTwenty - afterTwenty) < 0.1)
    }
}
