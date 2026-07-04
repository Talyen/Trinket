import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

/// End-to-end regression harness for battle simulation. Pins outcomes for a
/// fixed matchup and RNG seed so refactors cannot silently change combat behavior.
final class BattleGoldenPathTests: XCTestCase {
    private lazy var wizard = GameContent.heroes.first { $0.id == "wizard" }!
    private lazy var wolf = GameContent.pets.first { $0.id == "wolf" }!
    private lazy var goblin = GameContent.enemies.first { $0.id == "goblin" }!.combatant

    private func runGoldenBattle() -> BattleSimulationResult {
        BattleSimulator.run(
            BattleStateTestFactory.makeBattle(hero: wizard, pet: wolf, enemy: goblin),
            options: BattleSimulationOptions(maxTicks: 500, recordsEvents: true, recordsLog: true)
        )
    }

    func testGoldenPathOutcomeAndCounters() {
        let result = runGoldenBattle()

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 6)
        XCTAssertEqual(result.actionCount, 5)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.finalHeroHealth, 17)
        XCTAssertEqual(result.finalPetHealth, 19)
    }

    func testGoldenPathEventSemantics() {
        let result = runGoldenBattle()
        let events = result.events

        assertEndsWithVictoryMilestone(on: "goblin", events: events)
        XCTAssertTrue(events.contains { $0.kind == .ability && $0.keyword == .burn })
        XCTAssertTrue(events.contains { $0.kind == .ability && $0.keyword == .bleed })
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

    func testPartyDefeatGoldenPath() {
        let result = runPartyDefeatBattle()

        XCTAssertEqual(result.outcome, .defeat)
        XCTAssertEqual(result.tickCount, 18)
        XCTAssertEqual(result.actionCount, 13)
        XCTAssertEqual(result.finalHeroHealth, 0)
        XCTAssertEqual(result.finalPetHealth, 0)
        XCTAssertEqual(result.finalEnemyHealth, 100)
        assertEndsWithVictoryMilestone(on: "strong", events: result.events)
        XCTAssertTrue(result.events.contains { $0.kind == .ability && $0.keyword == .physical })
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

    func testStunThresholdGoldenPath() {
        let result = runStunThresholdBattle()

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 11)
        XCTAssertEqual(result.actionCount, 11)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        assertEndsWithVictoryMilestone(on: "enemy", events: result.events)
        XCTAssertTrue(result.events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        XCTAssertTrue(result.events.contains { $0.effectKind == .controlTriggered && $0.keyword == .stun })
        XCTAssertTrue(result.events.contains { $0.kind == .ability && $0.keyword == .stun })
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

    func testPoisonHeavyGoldenPath() {
        let result = runPoisonHeavyBattle()
        let events = result.events

        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.tickCount, 6)
        XCTAssertEqual(result.actionCount, 6)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        assertEndsWithVictoryMilestone(on: "enemy", events: events)
        XCTAssertTrue(events.filter { $0.kind == .ability && $0.keyword == .poison }.count >= 4)
        XCTAssertTrue(events.contains { $0.kind == .status && $0.keyword == .poison && $0.targetID == "enemy" })
    }

    // MARK: - Semantic helpers

    private func assertEndsWithVictoryMilestone(
        on targetID: String,
        events: [ActionEvent],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let milestones = events.filter { $0.kind == .milestone }
        XCTAssertFalse(milestones.isEmpty, file: file, line: line)
        XCTAssertEqual(milestones.last?.targetID, targetID, file: file, line: line)
    }

    private func assertContainsEvent(
        kind: ActionEvent.Kind,
        keyword: Keyword,
        targetID: String,
        in events: [ActionEvent],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            events.contains { $0.kind == kind && $0.keyword == keyword && $0.targetID == targetID },
            file: file,
            line: line
        )
    }
}
