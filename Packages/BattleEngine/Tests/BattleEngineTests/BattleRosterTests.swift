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
        initialHealth: Int? = nil,
        initialNextReadyAtTick: Int? = nil
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: combatant(id: id, role: role, maxHealth: maxHealth, actionIntervalTicks: actionIntervalTicks),
            initialHealth: initialHealth,
            initialNextReadyAtTick: initialNextReadyAtTick
        )
    }

    private func makeRoster(
        hero: CombatantRuntime? = nil,
        pet: CombatantRuntime? = nil,
        enemy: CombatantRuntime? = nil
    ) -> BattleRoster {
        BattleRoster(
            hero: hero ?? runtime(id: "hero", role: .hero, actionIntervalTicks: 2),
            pet: pet ?? runtime(id: "pet", role: .pet, actionIntervalTicks: 2),
            enemy: enemy ?? runtime(id: "enemy", role: .enemy, actionIntervalTicks: 6)
        )
    }

    // MARK: - Dispatch by Combatant identity

    @Test func effectTickOrderIsEnemyHeroPet() {
        #expect(BattleParticipant.effectTickOrder == [.enemy, .hero, .pet])
    }

    @Test func turnPriorityOrdersHeroBeforePetBeforeEnemy() {
        #expect(BattleParticipant.hero.turnPriority < BattleParticipant.pet.turnPriority)
        #expect(BattleParticipant.pet.turnPriority < BattleParticipant.enemy.turnPriority)
    }

    @Test func matchupCombatantForParticipant() {
        let hero = combatant(id: "hero", role: .hero)
        let pet = combatant(id: "pet", role: .pet)
        let enemy = combatant(id: "enemy", role: .enemy)
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        #expect(matchup.combatant(for: .hero).id == "hero")
        #expect(matchup.combatant(for: .pet).id == "pet")
        #expect(matchup.combatant(for: .enemy).id == "enemy")
    }

    @Test func runtimeForReturnsMatching() {
        let hero = runtime(id: "hero", role: .hero)
        let pet = runtime(id: "pet", role: .pet)
        let enemy = runtime(id: "enemy", role: .enemy)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        #expect(roster.runtime(for: hero.combatant)?.id == "hero")
        #expect(roster.runtime(for: pet.combatant)?.id == "pet")
        #expect(roster.runtime(for: enemy.combatant)?.id == "enemy")
    }

    @Test func runtimeForReturnsNilForUnknownID() {
        let roster = makeRoster()
        let unknown = combatant(id: "stranger", role: .hero)
        #expect(roster.runtime(for: unknown) == nil)
    }

    @Test func combatantForReturnsRuntimeByID() {
        let roster = makeRoster()
        #expect(roster.combatant(for: "hero")?.role == .hero)
        #expect(roster.combatant(for: "pet")?.role == .pet)
        #expect(roster.combatant(for: "enemy")?.role == .enemy)
        #expect(roster.combatant(for: "missing") == nil)
    }

    @Test func updateReplacesMatchingRuntime() {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(5)
        roster.update(hero)

        #expect(roster.hero.currentHealth == hero.maxHealth - 5)
        #expect(roster.pet.currentHealth == roster.pet.maxHealth)
    }

    @Test func updateIgnoresUnknownRuntime() {
        var roster = makeRoster()
        let stranger = runtime(id: "stranger", role: .hero)
        roster.update(stranger)
        #expect(roster.hero.id == "hero")
    }

    // MARK: - Active effects

    @Test func activeEffectsAndSetActiveEffects() {
        var roster = makeRoster()
        #expect(roster.activeEffects(for: roster.hero.combatant).isEmpty)

        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)
        roster.setActiveEffects([burn], for: roster.hero.combatant)
        #expect(roster.activeEffects(for: roster.hero.combatant) == [burn])
    }

    // MARK: - Health

    @Test func healthAndMaxHealth() {
        let hero = runtime(id: "hero", role: .hero, maxHealth: 10)
        let roster = BattleRoster(
            hero: hero,
            pet: runtime(id: "pet", role: .pet),
            enemy: runtime(id: "enemy", role: .enemy)
        )
        #expect(roster.health(for: hero.combatant) == 10)
        #expect(roster.maxHealth(for: hero.combatant) == 10)
    }

    // MARK: - Ready-actor picker

    @Test func readyCombatantsReturnsNothingBeforeAnyReady() {
        let roster = makeRoster()
        #expect(roster.readyCombatants(atTick: 0).isEmpty)
    }

    @Test func readyCombatantsRespectsIndividualReadyTicks() {
        let hero = runtime(id: "hero", role: .hero, actionIntervalTicks: 2)
        let pet = runtime(id: "pet", role: .pet, actionIntervalTicks: 4)
        let enemy = runtime(id: "enemy", role: .enemy, actionIntervalTicks: 6)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        #expect(roster.readyCombatants(atTick: 1).isEmpty)
        #expect(roster.readyCombatants(atTick: 2).map(\.id) == ["hero"])
        #expect(roster.readyCombatants(atTick: 3).map(\.id) == ["hero"])
        #expect(roster.readyCombatants(atTick: 4).map(\.id) == ["hero", "pet"])
        #expect(roster.readyCombatants(atTick: 5).map(\.id) == ["hero", "pet"])
        #expect(roster.readyCombatants(atTick: 6).map(\.id) == ["hero", "pet", "enemy"])
    }

    @Test func readyCombatantsSortsByReadyAtTickThenIntervalThenRoleOrder() {
        let fastPet = runtime(id: "fastpet", role: .pet, actionIntervalTicks: 1, initialNextReadyAtTick: 5)
        let slowHero = runtime(id: "slowhero", role: .hero, actionIntervalTicks: 4, initialNextReadyAtTick: 5)
        let roster = BattleRoster(
            hero: slowHero,
            pet: fastPet,
            enemy: runtime(id: "enemy", role: .enemy, actionIntervalTicks: 100)
        )
        // Both ready at tick 5. fastPet has longer interval (4 vs ... wait, 1 vs 4).
        // Sorted by interval descending → slowHero (4) first, then fastPet (1).
        let ready = roster.readyCombatants(atTick: 5)
        #expect(ready.map(\.id) == ["slowhero", "fastpet"])
    }

    @Test func readyCombatantsUsesRoleOrderTiebreaker() {
        // Same interval, same ready tick → hero (0) before pet (1) before enemy (2).
        let hero = runtime(id: "hero", role: .hero, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let pet = runtime(id: "pet", role: .pet, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let enemy = runtime(id: "enemy", role: .enemy, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)
        let ready = roster.readyCombatants(atTick: 2)
        #expect(ready.map(\.id) == ["hero", "pet", "enemy"])
    }

    @Test func readyCombatantsExcludesDefeated() {
        var roster = makeRoster()
        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        #expect(!(roster.readyCombatants(atTick: 100)).contains { $0.role == .enemy })
    }

    @Test func nextReadyRuntimeMatchesFirstReadyCombatant() {
        let hero = runtime(id: "hero", role: .hero, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let pet = runtime(id: "pet", role: .pet, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let enemy = runtime(id: "enemy", role: .enemy, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        for tick in 0 ... 6 {
            #expect(
                roster.nextReadyRuntime(atTick: tick)?.id == roster.readyCombatants(atTick: tick).first?.id
            )
        }
    }

    // MARK: - Targeting

    @Test func enemyAttackTargetPrefersHeroWhenBothAlive() {
        let roster = makeRoster()
        #expect(roster.enemyAttackTarget.id == "hero")
    }

    @Test func enemyAttackTargetFallsBackToPetWhenHeroDead() {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        #expect(roster.enemyAttackTarget.id == "pet")
    }

    @Test func enemyAttackTargetPrefersHigherHealthWhenBothAlive() {
        let hero = runtime(id: "hero", role: .hero, initialHealth: 5)
        let pet = runtime(id: "pet", role: .pet, initialHealth: 10)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: runtime(id: "enemy", role: .enemy))
        #expect(roster.enemyAttackTarget.id == "pet")
    }

    // MARK: - Defeat flags

    @Test func isPartyDefeatedRequiresBothDown() {
        var roster = makeRoster()
        #expect(!(roster.isPartyDefeated))

        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        #expect(!(roster.isPartyDefeated))

        var pet = roster.pet
        pet.takeRawDamage(999)
        roster.update(pet)
        #expect(roster.isPartyDefeated)
    }

    @Test func isEnemyDefeated() {
        var roster = makeRoster()
        #expect(!(roster.isEnemyDefeated))

        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        #expect(roster.isEnemyDefeated)
    }
}
