import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct BattleStateStartingHealthTests {
    @Test(arguments: [false, true])
    func `peak enemy depletion survives healing without observation`(tracksEvents: Bool) {
        var state = BattleState(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100),
            tracksLog: false, tracksEvents: tracksEvents, dealOpeningHand: false,
        )
        let initial = state
        state.roster.mutateRuntime(for: state.enemy) { runtime in
            _ = runtime.takeRawDamage(58)
            _ = runtime.heal(58)
        }
        #expect(state.health(of: state.enemy) == 100)
        #expect(state.defeatProgress.experienceAward(from: 100) == 29)
        state.roster.mutateRuntime(for: state.enemy) { runtime in
            _ = runtime.takeRawDamage(40)
            _ = runtime.heal(40)
        }
        #expect(state.defeatProgress.experienceAward(from: 100) == 29)
        #expect(initial.defeatProgress.experienceAward(from: 100) == 0)
    }

    @Test func `battle state seeds party starting health`() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 40),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30),
            heroStartingHealth: 17,
            companionStartingHealth: 9,
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentHealth == 17)
        #expect(state.roster.companion.currentHealth == 9)
        #expect(state.roster.enemy.currentHealth == 30)
    }

    @Test func `battle state defaults party to full health`() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 40),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30),
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentHealth == 50)
        #expect(state.roster.companion.currentHealth == 40)
    }
}
