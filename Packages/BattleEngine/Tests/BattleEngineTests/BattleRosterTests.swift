import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
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
        pet: CombatantRuntime? = nil,
        enemy: CombatantRuntime? = nil
    ) -> BattleRoster {
        BattleRoster(
            hero: hero ?? runtime(id: "hero", role: .hero),
            pet: pet ?? runtime(id: "pet", role: .pet),
            enemy: enemy ?? runtime(id: "enemy", role: .enemy)
        )
    }

    // MARK: - Dispatch by Combatant identity

    @Test func effectTickOrderIsEnemyHeroPet() throws {
        try #expect(BattleParticipant.effectTickOrder == [.enemy, .hero, .pet])
    }

    @Test func matchupCombatantForParticipant() throws {
        let hero = combatant(id: "hero", role: .hero)
        let pet = combatant(id: "pet", role: .pet)
        let enemy = combatant(id: "enemy", role: .enemy)
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        try #expect(matchup.combatant(for: .hero).id == "hero")
        try #expect(matchup.combatant(for: .pet).id == "pet")
        try #expect(matchup.combatant(for: .enemy).id == "enemy")
    }

    @Test func runtimeForReturnsMatching() throws {
        let hero = runtime(id: "hero", role: .hero)
        let pet = runtime(id: "pet", role: .pet)
        let enemy = runtime(id: "enemy", role: .enemy)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        try #expect(roster.runtime(for: hero.combatant)?.id == "hero")
        try #expect(roster.runtime(for: pet.combatant)?.id == "pet")
        try #expect(roster.runtime(for: enemy.combatant)?.id == "enemy")
    }

    @Test func runtimeForReturnsNilForUnknownID() throws {
        let roster = makeRoster()
        let unknown = combatant(id: "stranger", role: .hero)
        try #expect(roster.runtime(for: unknown) == nil)
    }

    @Test func combatantForReturnsRuntimeByID() throws {
        let roster = makeRoster()
        try #expect(roster.combatant(for: "hero")?.role == .hero)
        try #expect(roster.combatant(for: "pet")?.role == .pet)
        try #expect(roster.combatant(for: "enemy")?.role == .enemy)
        try #expect(roster.combatant(for: "missing") == nil)
    }

    @Test func updateReplacesMatchingRuntime() throws {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(5)
        roster.update(hero)

        try #expect(roster.hero.currentHealth == hero.maxHealth - 5)
        try #expect(roster.pet.currentHealth == roster.pet.maxHealth)
    }

    @Test func updateIgnoresUnknownRuntime() throws {
        var roster = makeRoster()
        let stranger = runtime(id: "stranger", role: .hero)
        roster.update(stranger)
        try #expect(roster.hero.id == "hero")
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

    @Test func healthAndMaxHealth() throws {
        let hero = runtime(id: "hero", role: .hero, maxHealth: 10)
        let roster = BattleRoster(
            hero: hero,
            pet: runtime(id: "pet", role: .pet),
            enemy: runtime(id: "enemy", role: .enemy)
        )
        try #expect(roster.health(for: hero.combatant) == 10)
        try #expect(roster.maxHealth(for: hero.combatant) == 10)
    }

    // MARK: - Targeting

    @Test func enemyAttackTargetPrefersHeroWhenBothAlive() throws {
        let roster = makeRoster()
        try #expect(roster.enemyAttackTarget.id == "hero")
    }

    @Test func enemyAttackTargetFallsBackToPetWhenHeroDead() throws {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        try #expect(roster.enemyAttackTarget.id == "pet")
    }

    @Test func enemyAttackTargetPrefersHigherHealthWhenBothAlive() throws {
        let hero = runtime(id: "hero", role: .hero, initialHealth: 5)
        let pet = runtime(id: "pet", role: .pet, initialHealth: 10)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: runtime(id: "enemy", role: .enemy))
        try #expect(roster.enemyAttackTarget.id == "pet")
    }

    // MARK: - Defeat flags

    @Test func isPartyDefeatedRequiresBothDown() throws {
        var roster = makeRoster()
        try #expect(!(roster.isPartyDefeated))

        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        try #expect(!(roster.isPartyDefeated))

        var pet = roster.pet
        pet.takeRawDamage(999)
        roster.update(pet)
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
