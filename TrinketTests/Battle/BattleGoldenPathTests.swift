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
        "status|-|Burn|1|goblin",
        "milestone|-|Physical|0|goblin"
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

    // MARK: - Party defeat

    private func runPartyDefeatBattle() -> BattleSimulationResult {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let strong = Combatant(
            id: "strong",
            name: "Strong",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: fragile, pet: helper, enemy: strong),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    private let partyDefeatFingerprints = [
        "ability|-|Physical|1|fragile",
        "effect|dodgeApplied|Dodge|0|helper",
        "ability|-|Physical|0|helper",
        "ability|-|Physical|1|helper",
        "milestone|-|Physical|0|strong"
    ]

    func testPartyDefeatGoldenPath() {
        let result = runPartyDefeatBattle()

        XCTAssertEqual(result.outcome, .defeat)
        XCTAssertEqual(result.tickCount, 18)
        XCTAssertEqual(result.actionCount, 13)
        XCTAssertEqual(result.finalHeroHealth, 0)
        XCTAssertEqual(result.finalPetHealth, 0)
        XCTAssertEqual(result.finalEnemyHealth, 100)
        XCTAssertEqual(result.events.map(eventFingerprint(_:)), partyDefeatFingerprints)
        XCTAssertTrue(result.log.contains { $0.text == "Your party has been defeated by Strong." })
    }

    // MARK: - Stun threshold

    private func runStunThresholdBattle() -> BattleSimulationResult {
        let stunHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [
                Ability(
                    id: "test-stun",
                    name: "Test Stun",
                    tier: .basic,
                    directDamage: 1,
                    damageKeyword: .stun,
                    description: "Deal 1 Stun damage."
                )
            ]
        )
        let silentPet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, actionIntervalTicks: 100, abilities: [])
        let stunEnemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 5, actionIntervalTicks: 2, abilities: [.slash])
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: stunHero, pet: silentPet, enemy: stunEnemy),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    private let stunThresholdFingerprints = [
        "effect|preventionTriggered|Stun|0|enemy",
        "ability|-|Stun|1|enemy",
        "effect|preventionSkipped|Stun|0|enemy",
        "effect|dodgeApplied|Dodge|0|enemy",
        "ability|-|Stun|0|enemy",
        "ability|-|Physical|1|hero",
        "effect|preventionTriggered|Stun|0|enemy",
        "ability|-|Stun|1|enemy",
        "effect|preventionSkipped|Stun|0|enemy",
        "effect|preventionTriggered|Stun|0|enemy",
        "ability|-|Stun|1|enemy",
        "effect|preventionSkipped|Stun|0|enemy",
        "effect|preventionTriggered|Stun|0|enemy",
        "ability|-|Stun|1|enemy",
        "effect|preventionSkipped|Stun|0|enemy",
        "ability|-|Stun|1|enemy",
        "milestone|-|Physical|0|enemy"
    ]

    func testStunThresholdGoldenPath() {
        let result = runStunThresholdBattle()

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 11)
        XCTAssertEqual(result.actionCount, 11)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.events.map(eventFingerprint(_:)), stunThresholdFingerprints)
        XCTAssertTrue(result.events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .stun })
    }

    // MARK: - Item modifier (Keen)

    private func runKeenAffixBattle() -> BattleSimulationResult {
        let keen = GameContent.itemAffixDefinitions.first { $0.id == "keen" }!
        let keenHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let idlePet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: [])
        let punchingBag = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(
                hero: keenHero,
                pet: idlePet,
                enemy: punchingBag,
                heroModifiers: CombatModifierProfile(modifiers: keen.basic.modifiers)
            ),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    func testKeenAffixGoldenPath() {
        let result = runKeenAffixBattle()
        let damagingHits = result.events.filter {
            $0.kind == .ability && $0.keyword == .physical && $0.amount > 0
        }

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 112)
        XCTAssertEqual(result.actionCount, 57)
        XCTAssertFalse(damagingHits.isEmpty)
        XCTAssertTrue(damagingHits.allSatisfy { $0.amount == 2 })
    }

    // MARK: - Poison-heavy

    private func runPoisonHeavyBattle() -> BattleSimulationResult {
        let poisonHero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [.poisonDagger]
        )
        let poisonPet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, actionIntervalTicks: 100, abilities: [])
        let poisonEnemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 40, actionIntervalTicks: 100, abilities: [])
        return BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: poisonHero, pet: poisonPet, enemy: poisonEnemy),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    private let poisonHeavyFingerprints = [
        "ability|-|Poison|3|enemy",
        "status|-|Poison|2|enemy",
        "effect|dodgeApplied|Dodge|0|enemy",
        "ability|-|Poison|0|enemy",
        "status|-|Poison|4|enemy",
        "ability|-|Poison|3|enemy",
        "status|-|Poison|6|enemy",
        "ability|-|Poison|3|enemy",
        "status|-|Poison|7|enemy",
        "ability|-|Poison|3|enemy",
        "status|-|Poison|8|enemy",
        "ability|-|Poison|1|enemy",
        "milestone|-|Physical|0|enemy"
    ]

    func testPoisonHeavyGoldenPath() {
        let result = runPoisonHeavyBattle()

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 6)
        XCTAssertEqual(result.actionCount, 6)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.events.map(eventFingerprint(_:)), poisonHeavyFingerprints)
    }
}
