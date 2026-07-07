import TrinketContent
import TrinketCore
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class BattleVictorySummaryTests: XCTestCase {
    func testMakeVictorySummaryIncludesStageAndBattleRewardsWhenVictory() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.freshStart
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
            stageReward: StageReward(gold: 12, itemTemplateIDs: ["shortsword-basic"])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
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

    func testMakeVictorySummaryScalesExperienceWhenEncounterLevelDiffers() throws {
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        var rosterState = PlayerRosterState.freshStart
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
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: .freshStart
        )
        let expectedPetXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)

        XCTAssertEqual(summary.experience, 0)
        XCTAssertEqual(summary.petExperience, expectedPetXP)
        XCTAssertEqual(summary.hasExperienceAwards, true)
        XCTAssertEqual(summary.petProgressionAfter.currentXP, expectedPetXP)
    }

    func testMakeVictorySummaryIncludesBattleGoldWhenRewardsGranted() throws {
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
        let session = BattleSession()
        session.activeBattle = configuration

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: .freshStart
        )

        XCTAssertEqual(summary.stageGold, 12)
        XCTAssertGreaterThanOrEqual(summary.battleGold, 0)
        XCTAssertEqual(summary.totalGold, summary.stageGold + summary.battleGold)
    }

    func testMakeVictorySummaryAppliesHomesteadBonusesWhenBonusesActive() throws {
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
        let session = BattleSession()
        session.activeBattle = configuration
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: XCTUnwrap(session.state),
            homestead: homestead
        )

        XCTAssertEqual(summary.materialRewards.first { $0.resource == .wood }?.quantity, 9)
        XCTAssertEqual(summary.materialRewards.first { $0.resource == .stone }?.quantity, 4)
    }
}
