import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EnemyCatchUpDamageTests {
    /// Party and enemy share maxHealth 100 so percentages map 1:1 with current HP.
    private func makeCatchUpContext(
        heroHP: Int,
        companionHP: Int,
        enemyHP: Int,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleEngineContext {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 100)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialHealth: heroHP),
            companion: CombatantRuntime(combatant: companion, initialHealth: companionHP),
            enemy: CombatantRuntime(combatant: enemy, initialHealth: enemyHP)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func reducesDamageWhenEnemyHPPercentExceedsPartyAverage() throws {
        // Enemy 80%, party avg 50% → penalty applies.
        var context = makeCatchUpContext(heroHP: 50, companionHP: 50, enemyHP: 80)
        let (lost, _) = context.applyTestDamage(
            6,
            to: context.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 5)
    }

    @Test func doesNotApplyWhenPercentagesAreEqual() throws {
        var context = makeCatchUpContext(heroHP: 50, companionHP: 50, enemyHP: 50)
        let (lost, _) = context.applyTestDamage(
            6,
            to: context.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 6)
    }

    @Test func doesNotApplyWhenEnemyIsBehind() throws {
        // Enemy 40%, party avg 80% → no penalty.
        var context = makeCatchUpContext(heroHP: 80, companionHP: 80, enemyHP: 40)
        let (lost, _) = context.applyTestDamage(
            6,
            to: context.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 6)
    }

    @Test func doesNotAffectPartySourcedDamage() throws {
        var context = makeCatchUpContext(heroHP: 50, companionHP: 50, enemyHP: 80)
        let (lost, _) = context.applyTestDamage(
            6,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: context.roster.hero.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 6)
    }

    @Test func floorsOutgoingDamageAtZero() throws {
        var context = makeCatchUpContext(heroHP: 50, companionHP: 50, enemyHP: 80)
        let (lost, _) = context.applyTestDamage(
            1,
            to: context.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: context.roster.enemy.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 0)
    }

    @Test(arguments: [Keyword.physical, Keyword.burn])
    func appliesAcrossDamageKeywords(keyword: Keyword) throws {
        var context = makeCatchUpContext(heroHP: 50, companionHP: 50, enemyHP: 80)
        let (lost, _) = context.applyTestDamage(
            6,
            to: context.roster.hero.combatant,
            keyword: keyword,
            sourceActorID: context.roster.enemy.id,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )
        try #expect(lost == 5, "\(keyword.rawValue)")
    }
}
