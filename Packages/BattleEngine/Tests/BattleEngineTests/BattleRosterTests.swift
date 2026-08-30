import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleRosterTests {
    private func combatant(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTurns: Int? = nil,
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
            abilities: [],
        )
    }

    private func runtime(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTurns: Int? = nil,
        initialHealth: Int? = nil,
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: combatant(id: id, role: role, maxHealth: maxHealth, actionIntervalTurns: actionIntervalTurns),
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

    @Test func `effect turn order is enemy hero companion`() throws {
        try #expect(BattleParticipant.effectTurnOrder == [.enemy, .hero, .companion])
    }

    @Test func `lookup helpers resolve participants by role and ID`() throws {
        let heroRuntime = runtime(id: "hero", role: .hero)
        let companionRuntime = runtime(id: "companion", role: .companion)
        let enemyRuntime = runtime(id: "enemy", role: .enemy)
        let roster = BattleRoster(hero: heroRuntime, companion: companionRuntime, enemy: enemyRuntime)

        try #expect(roster.runtime(for: heroRuntime.combatant)?.id == "hero")
        try #expect(roster.runtime(for: companionRuntime.combatant)?.id == "companion")
        try #expect(roster.runtime(for: enemyRuntime.combatant)?.id == "enemy")

        try #expect(roster.combatant(for: "hero")?.role == .hero)
        try #expect(roster.combatant(for: "companion")?.role == .companion)
        try #expect(roster.combatant(for: "enemy")?.role == .enemy)
        try #expect(roster.combatant(for: "missing") == nil)
    }

    @Test func `update replaces matching runtime`() throws {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(5)
        roster.update(hero)

        try #expect(roster.hero.currentHealth == hero.maxHealth - 5)
        try #expect(roster.companion.currentHealth == roster.companion.maxHealth)
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
