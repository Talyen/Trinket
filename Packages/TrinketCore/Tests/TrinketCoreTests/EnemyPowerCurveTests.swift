import Testing
@testable import TrinketCore

struct EnemyPowerCurveTests {
    @Test func anchorsMatchDesignTargets() throws {
        try #expect(abs(EnemyPowerCurve.power(level: 1, isBoss: false) - 4.20) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 20, isBoss: false) - 5.59) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 40, isBoss: false) - 9.30) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 1, isBoss: true) - 6.44) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 20, isBoss: true) - 10.77) < 0.001)
        try #expect(abs(EnemyPowerCurve.power(level: 40, isBoss: true) - 18.90) < 0.001)
    }

    @Test func curveIsContinuousAcrossBracketBoundaries() throws {
        let beforeTwenty = EnemyPowerCurve.power(level: 19, isBoss: false)
        let atTwenty = EnemyPowerCurve.power(level: 20, isBoss: false)
        let afterTwenty = EnemyPowerCurve.power(level: 21, isBoss: false)
        try #expect(EnemyPowerCurve.power(level: 1, isBoss: false) < atTwenty)
        try #expect(EnemyPowerCurve.power(level: 1, isBoss: true) < EnemyPowerCurve.power(level: 20, isBoss: true))
        try #expect(beforeTwenty < atTwenty)
        try #expect(atTwenty <= afterTwenty)
        try #expect(abs(atTwenty - afterTwenty) < 0.1)
    }
}
