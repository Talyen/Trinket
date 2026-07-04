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

    func testPruneExpiredFeedbackRemovesEventsPastDisplayDuration() throws {
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
        let now = Date()

        run.pruneExpiredFeedback(at: now)
        XCTAssertTrue(run.activeFeedbackEvents.contains { $0.id == eventID })

        run.pruneExpiredFeedback(
            at: now.addingTimeInterval(CombatFeedbackTiming.displayDuration + 0.1)
        )
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

    func testOutcomeReportsDefeatWhenPartyAndEnemyDefeatedTogether() {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            actionIntervalTicks: 1,
            abilities: [.faustianBargain]
        )
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 20,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 6,
            actionIntervalTicks: 100,
            abilities: []
        )
        let run = BattleRun(configuration: ActiveBattleConfiguration.make(hero: hero, pet: pet, enemy: enemy))

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        XCTAssertEqual(run.outcome, .defeat)
        XCTAssertTrue(run.isPartyDefeated)
        XCTAssertTrue(run.isEnemyDefeated)
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
            enemyEncounterLevel: 2,
            heroProgression: CombatantProgression(level: 2, currentXP: 10, requiredXP: 155),
            petProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
            stageReward: StageReward(gold: 12, itemTemplateIDs: []),
            rewardItemNames: ["Shortsword"]
        )
        let run = BattleRun(configuration: configuration)

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        let summary = run.makeVictorySummary(homestead: .freshStart)
        let expectedHeroXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 2)

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertEqual(summary.experience, expectedHeroXP)
        XCTAssertEqual(summary.heroName, hero.name)
        XCTAssertEqual(summary.petName, pet.name)
        XCTAssertEqual(summary.itemNames, ["Shortsword"])
        XCTAssertEqual(summary.heroProgressionBefore.level, 2)
        XCTAssertEqual(summary.heroProgressionAfter.currentXP, 10 + expectedHeroXP)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryScalesExperienceByEncounterLevel() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfiguration.make(
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: 1,
            heroProgression: CombatantProgression(level: 15, currentXP: 0, requiredXP: 100),
            petProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
            stageReward: StageReward(gold: 0, itemTemplateIDs: [])
        )
        let run = BattleRun(configuration: configuration)

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        let summary = run.makeVictorySummary(homestead: .freshStart)
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)

        XCTAssertEqual(summary.experience, 0)
        XCTAssertEqual(summary.petExperience, expectedPetXP)
        XCTAssertEqual(summary.hasExperienceAwards, true)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryIncludesBattleGoldAndTotalGold() {
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
            stageReward: StageReward(gold: 12, itemTemplateIDs: [])
        )
        let run = BattleRun(configuration: configuration)

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        let summary = run.makeVictorySummary(homestead: .freshStart)

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertGreaterThanOrEqual(summary.battleGold, 0)
        XCTAssertEqual(summary.totalGold, summary.stageGold + summary.battleGold)
    }

    func testMakeVictorySummaryAppliesHomesteadMaterialBonuses() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfiguration.make(
            hero: hero,
            pet: pet,
            enemy: enemy,
            stageReward: StageReward(
                gold: 0,
                itemTemplateIDs: [],
                materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)]
            )
        )
        let run = BattleRun(configuration: configuration)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])

        while run.outcome == .ongoing {
            _ = run.advanceOneStep()
        }

        let summary = run.makeVictorySummary(homestead: homestead)

        XCTAssertEqual(summary.materialRewards.first { $0.resource == .wood }?.quantity, 9)
        XCTAssertEqual(summary.materialRewards.first { $0.resource == .stone }?.quantity, 4)
    }
}
