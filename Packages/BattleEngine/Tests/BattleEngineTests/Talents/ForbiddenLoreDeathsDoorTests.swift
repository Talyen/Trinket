import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ForbiddenLoreDeathsDoorTests {
    @Test(arguments: [1, 2])
    func `Forbidden Lore restores Mana when Health loss enters Deaths Door`(initialHealth: Int) throws {
        let hero = try #require(GameContent.hero(matching: "warlock"))
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 40)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: CombatantFixtures.passiveCompanion(),
            enemy: enemy,
            heroHealth: initialHealth,
            heroMana: 0,
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_mana_t1_2"]),
        )
        battle.appliesFightPacing = false

        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: hero, keyword: .physical, sourceActorID: enemy.id,
            options: .attack(accuracy: .unavoidable),
        ))

        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.hero.hasConsumedDeathsDoor == (initialHealth == 1))
    }
}
