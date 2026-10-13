import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct FightPacingTests {
    @Test func `fight pacing keeps Health fractions when combined pools exceed integer capacity`() {
        let context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: Int.max),
            companion: CombatantFixtures.passiveCompanion(maxHealth: Int.max),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: Int.max),
            heroHealth: Int.max / 4, companionHealth: Int.max / 4, enemyHealth: Int.max / 2,
        )
        let metrics = FightPacing.poolMetrics(in: context)
        #expect(abs(metrics.partyFraction - 0.25) < 0.000_001)
        #expect(abs(metrics.enemyFraction - 0.5) < 0.000_001)
        #expect(abs(metrics.actualBurnFraction - 2.0 / 3.0) < 0.000_001)
    }

    private func makeContext(
        heroHP: Int = 50,
        companionHP: Int = 50,
        enemyHP: Int = 50,
        turnCount: Int = 0,
        enemyID: String = "goblin",
    ) -> BattleState {
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50),
            enemy: CombatantFixtures.combatant(id: enemyID, role: .enemy, maxHealth: 50),
            heroHealth: heroHP,
            companionHealth: companionHP,
            enemyHealth: enemyHP,
            rngSeed: 0,
            nextEffectID: 0,
            nextEventID: 0,
        )
        context.turnCount = turnCount
        return context
    }

    @Test func `even healthy fight has no bonuses`() throws {
        let context = makeContext(heroHP: 50, companionHP: 50, enemyHP: 50, turnCount: 1)
        let isBoss = FightPacing.isBossEnemy(in: context)
        try #expect(FightPacing.comebackMultiplier(side: .party, isBoss: isBoss, in: context) == 1.0)
        try #expect(FightPacing.comebackMultiplier(side: .enemy, isBoss: isBoss, in: context) == 1.0)
        try #expect(FightPacing.clockMultiplier(isBoss: isBoss, in: context) == 1.0)
    }

    @Test func `paced returns authored amount when fight pacing disabled`() {
        var context = makeContext(heroHP: 15, companionHP: 15, enemyHP: 45, turnCount: 8)
        context.appliesFightPacing = false
        #expect(context.paced(10, sourceActorID: context.hero.id) == 10)
    }

    @Test(arguments: [false, true])
    func `the trailing side receives the comeback bonus`(partyBehind: Bool) {
        let context = makeContext(
            heroHP: partyBehind ? 15 : 45, companionHP: partyBehind ? 15 : 45,
            enemyHP: partyBehind ? 45 : 10, turnCount: 4,
        )
        let isBoss = FightPacing.isBossEnemy(in: context)
        let party = FightPacing.comebackMultiplier(side: .party, isBoss: isBoss, in: context)
        let enemy = FightPacing.comebackMultiplier(side: .enemy, isBoss: isBoss, in: context)
        #expect((partyBehind ? party : enemy) >= 1.10)
        #expect((partyBehind ? enemy : party) == 1)
    }

    @Test(arguments: [(48, 48, 8, true), (30, 10, 6, false), (30, 25, 24, true)])
    func `clock accelerates stalled fights and the turn backstop`(partyHP: Int, enemyHP: Int, turn: Int, accelerates: Bool) {
        let context = makeContext(heroHP: partyHP, companionHP: partyHP, enemyHP: enemyHP, turnCount: turn, enemyID: "the_blight_treant")
        let clock = FightPacing.clockMultiplier(isBoss: FightPacing.isBossEnemy(in: context), in: context)
        #expect(accelerates ? clock >= 1.10 : clock == 1)
    }

    @Test func `paced scales authored damage for party source`() throws {
        var context = makeContext(heroHP: 15, companionHP: 15, enemyHP: 45, turnCount: 8, enemyID: "the_blight_treant")
        let scaled = context.paced(10, sourceActorID: "hero")
        try #expect(scaled > 10)
    }

    @Test func `paced leaves unattributed amounts unchanged`() throws {
        let context = makeContext(heroHP: 15, companionHP: 15, enemyHP: 45, turnCount: 8)
        try #expect(context.paced(10, sourceActorID: nil) == 10)
    }

    @Test func `stun buildup is not double paced when fight pacing active`() throws {
        let hero = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 100)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroHealth: 10,
            companionHealth: 10,
            enemyHealth: 100,
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            nextEffectID: 0,
            nextEventID: 0,
        )
        context.turnCount = 8

        let multiplier = FightPacing.multiplier(side: .party, isBoss: FightPacing.isBossEnemy(in: context), in: context)
        try #expect(multiplier > 1)

        let authored = 10
        let expectedOnce = CombatRounding.scaled(authored, multiplier: multiplier)
        let doublePaced = CombatRounding.scaled(expectedOnce, multiplier: multiplier)
        try #expect(doublePaced != expectedOnce)
        try #expect(expectedOnce < ControlMeterEngine.threshold(for: enemy, in: context))

        _ = context.resolveTestDamage(
            authored,
            to: context.roster.enemy.combatant,
            keyword: .stun,
            sourceActorID: "source",
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        )

        let amount = context.roster.enemy.activeEffects
            .first { $0.effect.kind == .controlMeter }?
            .effect.controlMeterValues?.amount
        try #expect(amount == expectedOnce)
        try #expect(amount != doublePaced)
    }
}
