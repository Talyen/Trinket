import XCTest
@testable import Trinket

/// End-to-end regression harness for battle simulation. Pins outcomes for a
/// fixed matchup and RNG seed so refactors cannot silently change combat behavior.
final class BattleGoldenPathTests: XCTestCase {
    private lazy var wizard = GameContent.heroes.first { $0.id == "wizard" }!
    private lazy var wolf = GameContent.pets.first { $0.id == "wolf" }!
    private lazy var goblin = GameContent.enemies.first { $0.id == "goblin" }!.combatant

    private let goldenEventFingerprints = [
        "effect|dodgeApplied|Dodge|0|goblin",
        "ability|-|Physical|0|goblin",
        "effect|dodgeApplied|Dodge|0|goblin",
        "ability|-|Burn|0|goblin",
        "status|-|Burn|1|goblin",
        "ability|-|Physical|2|goblin",
        "ability|-|Burn|3|goblin",
        "status|-|Burn|1|goblin",
        "ability|-|Bleed|4|goblin",
        "status|-|Bleed|4|goblin",
        "ability|-|Physical|1|wolf",
        "status|-|Bleed|4|goblin",
        "ability|-|Burn|5|goblin",
        "status|-|Bleed|4|goblin",
        "status|-|Burn|2|goblin",
        "ability|-|Physical|2|goblin",
        "status|-|Burn|1|goblin",
        "ability|-|Burn|3|goblin",
        "status|-|Burn|1|goblin"
    ]

    private let goldenLogText = """
        Wizard and Wolf face Goblin.
        Wolf uses Slash.
        Wizard uses Kindling on Goblin and applies Burning.
        Goblin takes 1 Burn damage.
        Wolf uses Slash for 2 Physical damage to Goblin.
        Wizard uses Kindling for 3 Burn damage to Goblin and applies Burning.
        Goblin takes 1 Burn damage.
        Wolf uses Serrated Edge for 4 Bleed damage to Goblin and applies Bleeding.
        Goblin takes 4 Bleed damage.
        Goblin uses Slash for 1 Physical damage to Wolf.
        Goblin takes 4 Bleed damage.
        Wizard uses Fireball for 5 Burn damage to Goblin and applies Burning.
        Goblin takes 4 Bleed damage.
        Goblin takes 2 Burn damage.
        Wolf uses Slash for 2 Physical damage to Goblin.
        Goblin takes 1 Burn damage.
        Wizard uses Kindling for 3 Burn damage to Goblin and applies Burning.
        Goblin takes 1 Burn damage.
        Goblin is defeated.
        """

    private func runGoldenBattle() -> BattleSimulationResult {
        BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: wizard, pet: wolf, enemy: goblin),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    private func eventFingerprint(_ event: ActionEvent) -> String {
        let effectKind = event.effectKind.map { String(describing: $0) } ?? "-"
        return "\(event.kind)|\(effectKind)|\(event.keyword.rawValue)|\(event.amount)|\(event.targetID)"
    }

    func testGoldenPathOutcomeAndCounters() {
        let result = runGoldenBattle()

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 10)
        XCTAssertEqual(result.actionCount, 9)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.finalHeroHealth, 10)
        XCTAssertEqual(result.finalPetHealth, 10)
    }

    func testGoldenPathEventFingerprints() {
        let result = runGoldenBattle()
        let fingerprints = result.events.map(eventFingerprint(_:))

        XCTAssertEqual(fingerprints, goldenEventFingerprints)
    }

    func testGoldenPathLogText() {
        let result = runGoldenBattle()
        let logText = result.log.map(\.text).joined(separator: "\n")

        XCTAssertEqual(logText, goldenLogText)
    }
}
