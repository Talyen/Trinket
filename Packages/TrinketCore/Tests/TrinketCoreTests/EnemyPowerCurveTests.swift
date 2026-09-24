import Testing
import TrinketCore

struct EnemyPowerCurveTests {
    @Test(arguments: [(1, 6.4, 7.5, 0.5, 0.2), (20, 16.0, 28.0, 1.2, 0.95), (40, 58.0, 85.0, 2.5, 2.3)])
    func `enemy power anchors match approved tuning`(
        level: Int,
        normalHP: Double,
        bossHP: Double,
        normalDamage: Double,
        bossDamage: Double,
    ) {
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

    @Test func `boss damage below normal at mid and late anchors is pinned`() {
        // Current tuning: boss trades damage for health at 20/40, pending
        // battle-owner review on whether that ordering is intentional.
        #expect(EnemyPowerCurve.rawDamagePercent(level: 20, isBoss: true) < EnemyPowerCurve.rawDamagePercent(level: 20, isBoss: false))
        #expect(EnemyPowerCurve.rawDamagePercent(level: 40, isBoss: true) < EnemyPowerCurve.rawDamagePercent(level: 40, isBoss: false))
        #expect(EnemyPowerCurve.health(level: 20, isBoss: true) > EnemyPowerCurve.health(level: 20, isBoss: false))
        #expect(EnemyPowerCurve.health(level: 40, isBoss: true) > EnemyPowerCurve.health(level: 40, isBoss: false))
    }

    @Test func `mid bracket values interpolate between anchors`() {
        let hp10 = EnemyPowerCurve.health(level: 10, isBoss: false)
        #expect(hp10 > 6.4)
        #expect(hp10 < 16.0)
        let damage30 = EnemyPowerCurve.rawDamagePercent(level: 30, isBoss: false)
        #expect(damage30 > 1.2)
        #expect(damage30 < 2.5)
    }

    @Test func `non positive levels clamp to the first anchor`() {
        #expect(EnemyPowerCurve.health(level: 0, isBoss: false) == EnemyPowerCurve.health(level: 1, isBoss: false))
        #expect(EnemyPowerCurve.health(level: -5, isBoss: true) == EnemyPowerCurve.health(level: 1, isBoss: true))
        #expect(EnemyPowerCurve.rawDamagePercent(level: 0, isBoss: false) == EnemyPowerCurve.rawDamagePercent(level: 1, isBoss: false))
    }

    @Test func `progression smoothstep clamps and eases`() {
        #expect(EnemyPowerCurve.progressionSmoothstep(0) == 0)
        #expect(EnemyPowerCurve.progressionSmoothstep(1) == 1)
        #expect(EnemyPowerCurve.progressionSmoothstep(-0.5) == 0)
        #expect(EnemyPowerCurve.progressionSmoothstep(1.5) == 1)
        #expect(abs(EnemyPowerCurve.progressionSmoothstep(0.5) - 0.5) < 0.000001)
        // NaN propagates (no clamping of non-finite); callers only pass [0, 1].
        #expect(EnemyPowerCurve.progressionSmoothstep(Double.nan).isNaN)
    }
}
