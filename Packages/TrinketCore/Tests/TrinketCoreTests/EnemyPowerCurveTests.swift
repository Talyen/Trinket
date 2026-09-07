import Testing
import TrinketCore

struct EnemyPowerCurveTests {
    @Test(arguments: [(1, 6.4, 7.5, 0.5, 0.6), (20, 16.0, 28.0, 1.2, 0.95), (40, 58.0, 85.0, 2.5, 2.3)])
    func `existing anchors stay unchanged`(level: Int, normalHP: Double, bossHP: Double, normalDamage: Double, bossDamage: Double) {
        #expect(abs(EnemyPowerCurve.health(level: level, isBoss: false) - normalHP) < 0.000001)
        #expect(abs(EnemyPowerCurve.health(level: level, isBoss: true) - bossHP) < 0.000001)
        #expect(abs(EnemyPowerCurve.rawDamagePercent(level: level, isBoss: false) - normalDamage) < 0.000001)
        #expect(abs(EnemyPowerCurve.rawDamagePercent(level: level, isBoss: true) - bossDamage) < 0.000001)
    }

    @Test(arguments: [false, true])
    func `high level health growth slows while damage stays linear`(isBoss: Bool) {
        let hp40 = EnemyPowerCurve.health(level: 40, isBoss: isBoss)
        let hp60 = EnemyPowerCurve.health(level: 60, isBoss: isBoss)
        let hp80 = EnemyPowerCurve.health(level: 80, isBoss: isBoss)
        #expect(hp60 > hp40)
        #expect(hp80 > hp60)
        #expect(hp80 - hp60 < hp60 - hp40)
        #expect(EnemyPowerCurve.health(level: 1000, isBoss: isBoss) > hp80)
        let damage40 = EnemyPowerCurve.rawDamagePercent(level: 40, isBoss: isBoss)
        let damage60 = EnemyPowerCurve.rawDamagePercent(level: 60, isBoss: isBoss)
        let damage80 = EnemyPowerCurve.rawDamagePercent(level: 80, isBoss: isBoss)
        #expect(damage60 > damage40)
        #expect(abs((damage80 - damage60) - (damage60 - damage40)) < 0.000001)
        #expect(EnemyPowerCurve.health(level: Int.max, isBoss: isBoss).isFinite)
        #expect(EnemyPowerCurve.rawDamagePercent(level: Int.max, isBoss: isBoss).isFinite)
    }
}
