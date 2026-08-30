import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleStateStartingHealthTests {
    private func combatant(id: String, role: Combatant.Role, maxHealth: Int) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            abilities: [],
        )
    }

    @Test func `battle state seeds party starting health`() {
        let state = BattleState(
            hero: combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: combatant(id: "companion", role: .companion, maxHealth: 40),
            enemy: combatant(id: "enemy", role: .enemy, maxHealth: 30),
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
            hero: combatant(id: "hero", role: .hero, maxHealth: 50),
            companion: combatant(id: "companion", role: .companion, maxHealth: 40),
            enemy: combatant(id: "enemy", role: .enemy, maxHealth: 30),
            dealOpeningHand: false,
        )

        #expect(state.roster.hero.currentHealth == 50)
        #expect(state.roster.companion.currentHealth == 40)
    }
}
