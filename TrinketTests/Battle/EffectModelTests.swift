import XCTest
@testable import Trinket

final class EffectModelTests: XCTestCase {
    func testAbilityUsesGeneratedDescription() {
        let ability = Ability.rayOfFrost
        XCTAssertEqual(ability.summary, "Deal 1 Freeze damage.")
    }

    func testAbilityHealHasNoDamage() {
        XCTAssertEqual(Ability.heal.summary, "Restore 3 Health.")
        XCTAssertEqual(Ability.heal.directDamage, 0)
    }
}
