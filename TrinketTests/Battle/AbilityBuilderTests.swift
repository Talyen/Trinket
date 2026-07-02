import XCTest
@testable import Trinket

final class AbilityBuilderTests: XCTestCase {
    func testDirectHitAddsPairedDoT() {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        XCTAssertEqual(ability.damageComponents, [DamageComponent(3, keyword: .burn)])
        XCTAssertTrue(ability.effects.contains { if case .burn(3) = $0 { return true }; return false })
        XCTAssertEqual(ability.summary, "Deal 3 Burn damage and applies Burning.")
    }

    func testBuffOnlyProducesGeneratedDescription() {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2, 6)]
        )
        XCTAssertEqual(ability.summary, "Gain Block.")
    }

    func testMultiDamageBuilder() {
        let ability = AbilityBuilder.multiDamage(
            id: "bloodthorn",
            name: "Bloodthorn",
            tier: .ultimate,
            damageComponents: [
                DamageComponent(2, keyword: .nature),
                DamageComponent(2, keyword: .bleed),
                DamageComponent(2, keyword: .poison)
            ],
            effects: [
                TargetedEffect(.bleed(2)),
                TargetedEffect(.poison(2)),
                TargetedEffect(.standardLeechBuff)
            ]
        )
        XCTAssertEqual(ability.summary, "Deal 2 Nature, 2 Bleed, and 2 Poison damage and Gain Leech.")
    }
}
