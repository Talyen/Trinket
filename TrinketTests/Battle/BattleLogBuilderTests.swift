import XCTest
@testable import Trinket

final class BattleLogBuilderTests: XCTestCase {
    func testNoDamageNoEffectsFallsBackToShortForm() {
        let line = BattleLogBuilder.lineForAction(
            actorName: "Hero",
            abilityName: "Block",
            dealt: 0,
            damageKeyword: .physical,
            targetName: "Enemy",
            appliedEffectSummaries: []
        )
        XCTAssertEqual(line, "Hero uses Block.")
    }

    func testDamageOnlyShowsDamageForm() {
        let line = BattleLogBuilder.lineForAction(
            actorName: "Hero",
            abilityName: "Slash",
            dealt: 3,
            damageKeyword: .physical,
            targetName: "Enemy",
            appliedEffectSummaries: []
        )
        XCTAssertEqual(line, "Hero uses Slash for 3 Physical damage to Enemy.")
    }

    func testEffectsOnlyShowsOnForm() {
        let line = BattleLogBuilder.lineForAction(
            actorName: "Hero",
            abilityName: "Smite",
            dealt: 0,
            damageKeyword: .holy,
            targetName: "Hero",
            appliedEffectSummaries: ["restore 3 Health"]
        )
        XCTAssertEqual(line, "Hero uses Smite on Hero and restore 3 Health.")
    }

    func testDamageAndEffectsCombines() {
        let line = BattleLogBuilder.lineForAction(
            actorName: "Hero",
            abilityName: "Fireball",
            dealt: 3,
            damageKeyword: .burn,
            targetName: "Enemy",
            appliedEffectSummaries: ["applies Burning"]
        )
        XCTAssertEqual(line, "Hero uses Fireball for 3 Burn damage to Enemy and applies Burning.")
    }

    func testMultipleEffectsJoinedByComma() {
        let line = BattleLogBuilder.lineForAction(
            actorName: "Hero",
            abilityName: "Heat Wave",
            dealt: 0,
            damageKeyword: .burn,
            targetName: "Enemy",
            appliedEffectSummaries: ["applies Burning", "gain Block"]
        )
        XCTAssertEqual(line, "Hero uses Heat Wave on Enemy and applies Burning, gain Block.")
    }
}
