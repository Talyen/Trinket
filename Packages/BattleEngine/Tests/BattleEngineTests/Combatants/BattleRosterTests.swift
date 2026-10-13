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

    @Test(arguments: [Combatant.Role.hero, .companion, .enemy])
    func `foreign combatants cannot read or overwrite a live participant`(role: Combatant.Role) {
        var roster = makeRoster()
        var foreign = runtime(id: "foreign", role: role)
        foreign.takeRawDamage(999)

        #expect(roster.participant(for: foreign.combatant) == nil)
        #expect(roster.runtime(for: foreign.combatant) == nil)
        #expect(roster.health(for: foreign.combatant) == 0)
        roster.update(foreign)
        roster.mutateRuntime(for: foreign.combatant) { $0.takeRawDamage(999) }
        #expect(roster.hero.currentHealth == 20)
        #expect(roster.companion.currentHealth == 20)
        #expect(roster.enemy.currentHealth == 20)
    }

    @Test func `identity selects the live runtime and rejects a mismatched role`() {
        var roster = makeRoster()
        let wrongRole = runtime(id: "hero", role: .enemy)
        roster.update(wrongRole)
        #expect(roster.runtime(for: wrongRole.combatant) == nil)
        #expect(roster.hero.combatant.role == .hero)
        #expect(roster.enemy.id == "enemy")

        var wounded = roster.hero
        wounded.takeRawDamage(7)
        roster.update(wounded)
        #expect(roster.health(for: roster.hero.combatant) == 13)
        #expect(roster.combatant(for: "hero")?.currentHealth == 13)
    }

    @Test func `modifier lookup cannot confuse a real ID with a role alias`() {
        let hero = runtime(id: "selected-hero", role: .hero).combatant
        let companion = runtime(id: "selected-companion", role: .companion).combatant
        let enemy = runtime(id: "hero", role: .enemy).combatant
        let battle = BattleState(
            hero: hero, companion: companion, enemy: enemy,
            heroModifiers: .init(maximumHealthBonus: 10),
            companionModifiers: .init(maximumHealthBonus: 20),
            enemyModifiers: .init(maximumHealthBonus: 30),
            dealOpeningHand: false,
        )
        #expect(battle.modifiers(for: hero.id).maximumHealthBonus == 10)
        #expect(battle.modifiers(for: companion.id).maximumHealthBonus == 20)
        #expect(battle.modifiers(for: enemy.id).maximumHealthBonus == 30)
        #expect(battle.modifiers(for: "companion") == .zero)
        #expect(battle.modifiers(for: "enemy") == .zero)
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
