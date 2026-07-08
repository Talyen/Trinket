import Testing
import TrinketContent
import TrinketCore

@Suite
struct CombatantModelTests {
    @Test func combatantDefaultsToZeroPrimaryStats() {
        let hero = Combatant(id: "h", name: "H", role: .hero, maxHealth: 10, abilities: [.slash])
        #expect(hero.primaryStats == PrimaryStats())
    }
}
