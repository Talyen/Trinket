import Testing
import TrinketContent
import TrinketCore

struct CombatantModelTests {
    @Test func combatantDefaultsToZeroPrimaryStats() throws {
        let hero = Combatant(id: "h", name: "H", role: .hero, maxHealth: 10, abilities: [.slash])
        try #expect(hero.primaryStats == PrimaryStats())
    }
}
