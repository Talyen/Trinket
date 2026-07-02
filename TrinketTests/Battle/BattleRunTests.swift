import XCTest
@testable import Trinket

@MainActor
final class BattleRunTests: XCTestCase {
    func testAdvanceOneStepAppendsNonMilestoneEvents() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            maxHealth: 20,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let configuration = ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy)
        let run = BattleRun(configuration: configuration)

        _ = run.advanceOneStep()

        XCTAssertFalse(run.activeFeedbackEvents.isEmpty)
        XCTAssertTrue(run.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testAdvanceOneStepExcludesMilestonesWhenBattleEnds() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let configuration = ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy)
        let run = BattleRun(configuration: configuration)

        while !run.isBattleOver {
            _ = run.advanceOneStep()
        }

        XCTAssertTrue(run.isPartyDefeated)
        XCTAssertTrue(run.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testResetClearsFeedbackAndRebuildsState() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let configuration = ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy)
        let run = BattleRun(configuration: configuration)

        _ = run.advanceOneStep()
        _ = run.advanceOneStep()
        XCTAssertFalse(run.activeFeedbackEvents.isEmpty)
        XCTAssertLessThan(run.enemyHealth, 100)

        run.reset(from: configuration)

        XCTAssertTrue(run.activeFeedbackEvents.isEmpty)
        XCTAssertEqual(run.enemyHealth, 100)
        XCTAssertEqual(run.heroHealth, hero.maxHealth)
    }

    func testRemoveFeedbackEventRemovesByID() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let configuration = ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy)
        let run = BattleRun(configuration: configuration)

        _ = run.advanceOneStep()
        let eventID = try XCTUnwrap(run.activeFeedbackEvents.first?.id)

        run.removeFeedbackEvent(eventID)

        XCTAssertTrue(run.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    func testOutcomeReportsOngoingDuringBattle() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        let run = BattleRun(configuration: ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy))

        _ = run.advanceOneStep()

        XCTAssertEqual(run.outcome, .ongoing)
    }

    func testOutcomeReportsVictoryWhenEnemyDefeated() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let run = BattleRun(configuration: ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy))

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        XCTAssertEqual(run.outcome, .victory)
    }

    func testOutcomeReportsDefeatWhenPartyDefeated() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let run = BattleRun(configuration: ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy))

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        XCTAssertEqual(run.outcome, .defeat)
    }

    func testMakeVictorySummaryIncludesStageAndBattleRewards() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfiguration.make(
            stageID: "chapter-1-stage-1",
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroProgression: CombatantProgression(level: 2, currentXP: 10, requiredXP: 50),
            petProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 25),
            stageReward: StageReward(gold: 12, experience: 8, itemTemplateIDs: []),
            rewardItemNames: ["Shortsword"]
        )
        let run = BattleRun(configuration: configuration)

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        let summary = run.makeVictorySummary()

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertEqual(summary.experience, 8)
        XCTAssertEqual(summary.heroName, hero.name)
        XCTAssertEqual(summary.petName, pet.name)
        XCTAssertEqual(summary.itemNames, ["Shortsword"])
        XCTAssertEqual(summary.heroProgressionBefore.level, 2)
        XCTAssertEqual(summary.heroProgressionAfter.currentXP, 18)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, 8)
    }
}
