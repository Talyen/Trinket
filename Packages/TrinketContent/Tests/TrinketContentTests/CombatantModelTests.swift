import XCTest
import TrinketContent
import TrinketCore

final class CombatantModelTests: XCTestCase {
    func testCombatantDefaultsToZeroPrimaryStats() {
        let hero = Combatant(id: "h", name: "H", role: .hero, maxHealth: 10, abilities: [.slash])
        XCTAssertEqual(hero.primaryStats, PrimaryStats())
    }
}
