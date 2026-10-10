import Testing
import TrinketCore

struct EnemyPowerCurveTests {
    @Test(arguments: [
        (EnemyPowerCurve.Profile.standard, 1, 6.4, 15.0, 0.5, 0.25),
        (.standard, 20, 16.0, 28.0, 4.3, 2.2),
        (.standard, 40, 44.0, 75.0, 15.0, 6.5),
        (.spire, 1, 6.4, 10.0, 0.5, 0.35),
        (.spire, 20, 16.0, 28.0, 1.6, 1.1),
        (.spire, 40, 35.2, 60.0, 3.25, 3.25),
        (.recovery, 1, 6.4, 10.0, 0.5, 0.35),
        (.recovery, 20, 16.0, 28.0, 1.6, 1.1),
        (.recovery, 40, 44.0, 75.0, 3.25, 3.25),
    ])
    func `enemy power anchors match approved tuning`(
        profile: EnemyPowerCurve.Profile,
        level: Int,
        normalHP: Double,
        bossHP: Double,
        normalDamage: Double,
        bossDamage: Double,
    ) {
        #expect(abs(EnemyPowerCurve.health(level: level, isBoss: false, profile: profile) - normalHP) < 0.000001)
        #expect(abs(EnemyPowerCurve.health(level: level, isBoss: true, profile: profile) - bossHP) < 0.000001)
        #expect(abs(EnemyPowerCurve.rawDamagePercent(level: level, isBoss: false, profile: profile) - normalDamage) < 0.000001)
        #expect(abs(EnemyPowerCurve.rawDamagePercent(level: level, isBoss: true, profile: profile) - bossDamage) < 0.000001)
    }

    @Test(arguments: [false, true], EnemyPowerCurve.Profile.allCases)
    func `high level health growth slows while damage stays linear`(isBoss: Bool, profile: EnemyPowerCurve.Profile) {
        let hp40 = EnemyPowerCurve.health(level: 40, isBoss: isBoss, profile: profile)
        let hp60 = EnemyPowerCurve.health(level: 60, isBoss: isBoss, profile: profile)
        let hp80 = EnemyPowerCurve.health(level: 80, isBoss: isBoss, profile: profile)
        #expect(hp60 > hp40)
        #expect(hp80 > hp60)
        #expect(hp80 - hp60 < hp60 - hp40)
        #expect(EnemyPowerCurve.health(level: 1000, isBoss: isBoss, profile: profile) > hp80)
        let damage40 = EnemyPowerCurve.rawDamagePercent(level: 40, isBoss: isBoss, profile: profile)
        let damage60 = EnemyPowerCurve.rawDamagePercent(level: 60, isBoss: isBoss, profile: profile)
        let damage80 = EnemyPowerCurve.rawDamagePercent(level: 80, isBoss: isBoss, profile: profile)
        #expect(damage60 > damage40)
        #expect(abs((damage80 - damage60) - (damage60 - damage40)) < 0.000001)
        #expect(EnemyPowerCurve.health(level: Int.max, isBoss: isBoss, profile: profile).isFinite)
        #expect(EnemyPowerCurve.rawDamagePercent(level: Int.max, isBoss: isBoss, profile: profile).isFinite)
    }

    @Test func `mid bracket values interpolate between anchors`() {
        let hp10 = EnemyPowerCurve.health(level: 10, isBoss: false)
        #expect(hp10 > 6.4)
        #expect(hp10 < 16.0)
        let damage30 = EnemyPowerCurve.rawDamagePercent(level: 30, isBoss: false)
        #expect(damage30 > EnemyPowerCurve.rawDamagePercent(level: 20, isBoss: false))
        #expect(damage30 < EnemyPowerCurve.rawDamagePercent(level: 40, isBoss: false))
    }

    @Test func `non positive levels clamp to the first anchor`() {
        #expect(EnemyPowerCurve.health(level: 0, isBoss: false) == EnemyPowerCurve.health(level: 1, isBoss: false))
        #expect(EnemyPowerCurve.health(level: -5, isBoss: true) == EnemyPowerCurve.health(level: 1, isBoss: true))
        #expect(EnemyPowerCurve.rawDamagePercent(level: 0, isBoss: false) == EnemyPowerCurve.rawDamagePercent(level: 1, isBoss: false))
    }
}
