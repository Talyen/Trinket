import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct FightPacingTests {
    private func makeContext(
        heroHP: Int = 50,
        companionHP: Int = 50,
        enemyHP: Int = 50,
        turnCount: Int = 0,
        enemyID: String = "goblin",
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: enemyID, role: .enemy, maxHealth: 50)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroHealth: heroHP,
            companionHealth: companionHP,
            enemyHealth: enemyHP,
            seed: 0,
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

    @Test func `party behind grants party comeback at least ten percent`() throws {
        let context = makeContext(heroHP: 15, companionHP: 15, enemyHP: 45, turnCount: 4)
        let isBoss = FightPacing.isBossEnemy(in: context)
        let partyMult = FightPacing.comebackMultiplier(side: .party, isBoss: isBoss, in: context)
        let enemyMult = FightPacing.comebackMultiplier(side: .enemy, isBoss: isBoss, in: context)
        try #expect(partyMult >= 1.10)
        try #expect(enemyMult == 1.0)
    }

    @Test func `enemy behind grants enemy comeback at least ten percent`() throws {
        let context = makeContext(heroHP: 45, companionHP: 45, enemyHP: 10, turnCount: 4)
        let isBoss = FightPacing.isBossEnemy(in: context)
        let partyMult = FightPacing.comebackMultiplier(side: .party, isBoss: isBoss, in: context)
        let enemyMult = FightPacing.comebackMultiplier(side: .enemy, isBoss: isBoss, in: context)
        try #expect(partyMult == 1.0)
        try #expect(enemyMult >= 1.10)
    }

    @Test func `stalled fight activates clock early`() throws {
        let context = makeContext(heroHP: 48, companionHP: 48, enemyHP: 48, turnCount: 8, enemyID: "the_blight_treant")
        let isBoss = FightPacing.isBossEnemy(in: context)
        let clock = FightPacing.clockMultiplier(isBoss: isBoss, in: context)
        try #expect(clock >= 1.10)
    }

    @Test func `fast fight stays off clock`() throws {
        let context = makeContext(heroHP: 30, companionHP: 30, enemyHP: 10, turnCount: 6, enemyID: "the_blight_treant")
        try #expect(FightPacing.clockMultiplier(isBoss: FightPacing.isBossEnemy(in: context), in: context) == 1.0)
    }

    @Test func `turn backstop escalates past max rounds`() throws {
        let context = makeContext(heroHP: 30, companionHP: 30, enemyHP: 25, turnCount: 24, enemyID: "the_blight_treant")
        let isBoss = FightPacing.isBossEnemy(in: context)
        let clock = FightPacing.clockMultiplier(isBoss: isBoss, in: context)
        try #expect(clock >= 1.10)
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
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroHealth: 10,
            companionHealth: 10,
            enemyHealth: 100,
            seed: CombatantFixtures.deterministicBattleSeed,
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

        _ = context.applyTestDamage(
            authored,
            to: context.roster.enemy.combatant,
            keyword: .stun,
            sourceActorID: "source",
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false,
        )

        let amount = context.roster.enemy.activeEffects
            .first(where: \.effect.isControlMeter)?
            .effect.controlMeterValues?.amount
        try #expect(amount == expectedOnce)
        try #expect(amount != doublePaced)
    }
}
