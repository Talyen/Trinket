import TrinketContent
import TrinketCore
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class BattleRunTests: XCTestCase {
    private func makeSession(configuration: ActiveBattleConfiguration) -> BattleSession {
        let session = BattleSession()
        session.activeBattle = configuration
        return session
    }

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
        let configuration = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        let session = makeSession(configuration: configuration)

        _ = session.advanceOneStep()

        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
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
        let configuration = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        let session = makeSession(configuration: configuration)

        while !(session.state?.isBattleOver ?? true) {
            _ = session.advanceOneStep()
        }

        XCTAssertTrue(session.state?.isPartyDefeated == true)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
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
        let configuration = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        let session = makeSession(configuration: configuration)

        _ = session.advanceOneStep()
        _ = session.advanceOneStep()
        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertLessThan(session.state?.health(of: session.state?.enemy ?? enemy) ?? 0, 100)

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(session.activeFeedbackEvents.isEmpty)
        XCTAssertEqual(session.state?.health(of: session.state?.enemy ?? enemy), 100)
        XCTAssertEqual(session.state?.health(of: session.state?.hero ?? hero), hero.maxHealth)
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
        let configuration = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        let session = makeSession(configuration: configuration)

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
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
        let configuration = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        let session = makeSession(configuration: configuration)

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)
        let now = Date()

        session.pruneExpiredFeedback(at: now)
        XCTAssertTrue(session.activeFeedbackEvents.contains { $0.id == eventID })

        session.pruneExpiredFeedback(
            at: now.addingTimeInterval(CombatFeedbackTiming.displayDuration + 0.1)
        )
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
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
        let session = makeSession(configuration: ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy))

        _ = session.advanceOneStep()

        XCTAssertNil(session.outcome)
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
        let session = makeSession(configuration: ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy))

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
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
        let session = makeSession(configuration: ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy))

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .defeat)
    }

    func testOutcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() {
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
        let session = makeSession(configuration: ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy))

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
        XCTAssertFalse(session.state?.isPartyDefeated ?? true)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
    }

    func testOutcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = makeSession(configuration: ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy))

        XCTAssertTrue(session.state?.isPartyDefeated ?? false)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
        XCTAssertEqual(session.outcome, .victory)
    }

    func testMakeVictorySummaryIncludesStageAndBattleRewards() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.initial
        rosterState.progressions[hero.id] = CombatantProgression(level: 2, currentXP: 10, requiredXP: 155)
        rosterState.progressions[pet.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: 2,
            roster: rosterState,
            stageReward: StageReward(gold: 12, itemTemplateIDs: []),
            rewardItemNames: ["Shortsword"]
        )
        let session = makeSession(configuration: configuration)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: try XCTUnwrap(session.state),
            homestead: .freshStart
        )
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

    func testMakeVictorySummaryScalesExperienceByEncounterLevel() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.initial
        rosterState.progressions[hero.id] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        rosterState.progressions[pet.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEncounterLevel: 1,
            roster: rosterState,
            stageReward: StageReward(gold: 0, itemTemplateIDs: [])
        )
        let session = makeSession(configuration: configuration)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: try XCTUnwrap(session.state),
            homestead: .freshStart
        )
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)

        XCTAssertEqual(summary.experience, 0)
        XCTAssertEqual(summary.petExperience, expectedPetXP)
        XCTAssertEqual(summary.hasExperienceAwards, true)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryIncludesBattleGoldAndTotalGold() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: [])
        )
        let session = makeSession(configuration: configuration)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: try XCTUnwrap(session.state),
            homestead: .freshStart
        )

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertGreaterThanOrEqual(summary.battleGold, 0)
        XCTAssertEqual(summary.totalGold, summary.stageGold + summary.battleGold)
    }

    func testMakeVictorySummaryAppliesHomesteadMaterialBonuses() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy,
            stageReward: StageReward(
                gold: 0,
                itemTemplateIDs: [],
                materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)]
            )
        )
        let session = makeSession(configuration: configuration)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: try XCTUnwrap(session.state),
            homestead: homestead
        )

        XCTAssertEqual(summary.materialRewards.first { $0.resource == .wood }?.quantity, 9)
        XCTAssertEqual(summary.materialRewards.first { $0.resource == .stone }?.quantity, 4)
    }
}
