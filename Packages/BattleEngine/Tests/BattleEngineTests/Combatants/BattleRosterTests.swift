import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct BattleRosterTests {
    private func runtime(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        initialHealth: Int? = nil,
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: CombatantFixtures.combatant(id: id, role: role, maxHealth: maxHealth),
            initialHealth: initialHealth,
        )
    }

    private func makeRoster(
        hero: CombatantRuntime? = nil,
        companion: CombatantRuntime? = nil,
        enemy: CombatantRuntime? = nil,
    ) -> BattleRoster {
        BattleRoster(
            hero: hero ?? runtime(id: "hero", role: .hero),
            companion: companion ?? runtime(id: "companion", role: .companion),
            enemy: enemy ?? runtime(id: "enemy", role: .enemy),
        )
    }

    @Test func `enemy attack target covers alive dead and health priority`() throws {
        let aliveRoster = makeRoster()
        try #expect(aliveRoster.enemyAttackTarget.id == "hero")

        var woundedRoster = makeRoster()
        var hero = woundedRoster.hero
        hero.takeRawDamage(999)
        woundedRoster.update(hero)
        try #expect(woundedRoster.enemyAttackTarget.id == "companion")

        let priorityHero = runtime(id: "hero", role: .hero, initialHealth: 5)
        let priorityCompanion = runtime(id: "companion", role: .companion, initialHealth: 10)
        let priorityRoster = BattleRoster(hero: priorityHero, companion: priorityCompanion, enemy: runtime(id: "enemy", role: .enemy))
        try #expect(priorityRoster.enemyAttackTarget.id == "companion")
    }

    @Test func `defeat flags cover party and enemy`() throws {
        var roster = makeRoster()
        try #expect(!(roster.isPartyDefeated))
        try #expect(!(roster.isEnemyDefeated))

        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        try #expect(!(roster.isPartyDefeated))

        var companion = roster.companion
        companion.takeRawDamage(999)
        roster.update(companion)
        try #expect(roster.isPartyDefeated)

        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        try #expect(roster.isEnemyDefeated)
    }
}
