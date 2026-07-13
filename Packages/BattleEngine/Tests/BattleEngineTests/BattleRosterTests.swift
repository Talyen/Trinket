import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleRosterTests {
    private func combatant(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int? = nil
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: []
        )
    }

    private func runtime(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int? = nil,
        initialHealth: Int? = nil
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: combatant(id: id, role: role, maxHealth: maxHealth, actionIntervalTicks: actionIntervalTicks),
            initialHealth: initialHealth
        )
    }

    private func makeRoster(
        hero: CombatantRuntime? = nil,
        companion: CombatantRuntime? = nil,
        enemy: CombatantRuntime? = nil
    ) -> BattleRoster {
        BattleRoster(
            hero: hero ?? runtime(id: "hero", role: .hero),
            companion: companion ?? runtime(id: "companion", role: .companion),
            enemy: enemy ?? runtime(id: "enemy", role: .enemy)
        )
    }

    // MARK: - Dispatch by Combatant identity

    @Test func effectTickOrderIsEnemyHeroCompanion() throws {
        try #expect(BattleParticipant.effectTickOrder == [.enemy, .hero, .companion])
    }

    @Test func matchupCombatantForParticipant() throws {
        let hero = combatant(id: "hero", role: .hero)
        let companion = combatant(id: "companion", role: .companion)
        let enemy = combatant(id: "enemy", role: .enemy)
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)

        try #expect(matchup.combatant(for: .hero).id == "hero")
        try #expect(matchup.combatant(for: .companion).id == "companion")
        try #expect(matchup.combatant(for: .enemy).id == "enemy")
    }

    @Test func runtimeForReturnsMatching() throws {
        let hero = runtime(id: "hero", role: .hero)
        let companion = runtime(id: "companion", role: .companion)
        let enemy = runtime(id: "enemy", role: .enemy)
        let roster = BattleRoster(hero: hero, companion: companion, enemy: enemy)

        try #expect(roster.runtime(for: hero.combatant)?.id == "hero")
        try #expect(roster.runtime(for: companion.combatant)?.id == "companion")
        try #expect(roster.runtime(for: enemy.combatant)?.id == "enemy")
    }

    @Test func combatantForReturnsRuntimeByID() throws {
        let roster = makeRoster()
        try #expect(roster.combatant(for: "hero")?.role == .hero)
        try #expect(roster.combatant(for: "companion")?.role == .companion)
        try #expect(roster.combatant(for: "enemy")?.role == .enemy)
        try #expect(roster.combatant(for: "missing") == nil)
    }

    @Test func updateReplacesMatchingRuntime() throws {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(5)
        roster.update(hero)

        try #expect(roster.hero.currentHealth == hero.maxHealth - 5)
        try #expect(roster.companion.currentHealth == roster.companion.maxHealth)
    }

    // MARK: - Active effects

    @Test func activeEffectsAndSetActiveEffects() throws {
        var roster = makeRoster()
        try #expect(roster.activeEffects(for: roster.hero.combatant).isEmpty)

        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)
        roster.setActiveEffects([burn], for: roster.hero.combatant)
        try #expect(roster.activeEffects(for: roster.hero.combatant) == [burn])
    }

    // MARK: - Health

    // MARK: - Targeting

    @Test func enemyAttackTargetCoversAliveDeadAndHealthPriority() throws {
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

    // MARK: - Defeat flags

    @Test func isPartyDefeatedRequiresBothDown() throws {
        var roster = makeRoster()
        try #expect(!(roster.isPartyDefeated))

        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        try #expect(!(roster.isPartyDefeated))

        var companion = roster.companion
        companion.takeRawDamage(999)
        roster.update(companion)
        try #expect(roster.isPartyDefeated)
    }

    @Test func isEnemyDefeated() throws {
        var roster = makeRoster()
        try #expect(!(roster.isEnemyDefeated))

        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        try #expect(roster.isEnemyDefeated)
    }
}
