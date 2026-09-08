import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct BattleStateStartingHealthTests {
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
