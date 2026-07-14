import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import Trinket

@MainActor
struct BattleVictorySummaryTests {
    @Test func makeVictorySummaryIncludesStageAndBattleRewardsWhenVictory() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        var rosterState = PlayerRosterState.freshStart
        rosterState.progressions[hero.id] = CombatantProgression(level: 2, currentXP: 10, requiredXP: 155)
        rosterState.progressions[companion.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            roster: rosterState,
            stageReward: StageReward(gold: 12, itemTemplateIDs: ["shortsword-basic"])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: state,
            homestead: .freshStart
        )
        let expectedHeroXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedCompanionXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 2)

        #expect(summary.stageGold == 12)
        #expect(summary.experience == expectedHeroXP)
        #expect(summary.heroName == hero.name)
        #expect(summary.companionName == companion.name)
        #expect(summary.heroArtworkName == hero.artReference?.thumbnailImageName)
        #expect(summary.companionArtworkName == companion.artReference?.thumbnailImageName)
        #expect(summary.rewardItems.map(\.displayName) == ["Shortsword"])
        #expect(summary.rewardItems.first?.id == "chapter-1-stage-1-shortsword-basic")
        #expect(summary.rewardItems.first?.affixes.isEmpty == false)
        #expect(summary.heroProgressionBefore.level == 2)
        #expect(summary.heroProgressionAfter.currentXP == 10 + expectedHeroXP)
        #expect(summary.companionProgressionAfter.currentXP == expectedCompanionXP)
    }

    @Test func makeVictorySummaryScalesExperienceWhenEncounterLevelDiffers() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        var rosterState = PlayerRosterState.freshStart
        rosterState.progressions[hero.id] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        rosterState.progressions[companion.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 1,
            roster: rosterState,
            stageReward: StageReward(gold: 0, itemTemplateIDs: [])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: state,
            homestead: .freshStart
        )
        let expectedCompanionXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)

        #expect(summary.experience == 0)
        #expect(summary.companionExperience == expectedCompanionXP)
        #expect(summary.hasExperienceAwards == true)
        #expect(summary.rewardItems.isEmpty)
        #expect(summary.companionProgressionAfter.currentXP == expectedCompanionXP)
    }

    @Test func makeVictorySummaryIncludesBattleGoldWhenRewardsGranted() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: [])
        )
        let session = BattleSession()
        session.activeBattle = configuration

        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: state,
            homestead: .freshStart
        )

        #expect(summary.stageGold == 12)
        #expect(summary.battleGold >= 0)
        #expect(summary.totalGold == summary.stageGold + summary.battleGold)
    }

    @Test func makeVictorySummaryAppliesHomesteadBonusesWhenBonusesActive() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
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

        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: state,
            homestead: homestead
        )

        #expect(summary.materialRewards.first { $0.resource == .wood }?.quantity == 8)
        #expect(summary.materialRewards.first { $0.resource == .stone }?.quantity == 3)
    }

    @Test func makeVictorySummaryAppliesLabyrinthExperienceBonusPercent() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        var rosterState = PlayerRosterState.freshStart
        rosterState.progressions[hero.id] = CombatantProgression(level: 2, currentXP: 0, requiredXP: 155)
        rosterState.progressions[companion.id] = CombatantProgression(level: 2, currentXP: 0, requiredXP: 155)
        let pendingItem = InventoryItem(
            id: "labyrinth-audit-node",
            templateID: "audit-basic",
            baseType: try #require(GameContent.itemBaseTypes.first),
            rarity: .basic,
            displayName: "Audit Find",
            affixes: []
        )
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            labyrinthBattle: .init(nodeID: "audit-node"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            roster: rosterState,
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            experienceBonusPercent: 20,
            pendingRewardItem: pendingItem
        )
        let session = BattleSession()
        session.activeBattle = configuration
        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: state,
            homestead: .freshStart
        )
        let baseXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedXP = LabyrinthCompletion.adjustedExperienceAward(baseXP, xpPercent: 20)

        #expect(summary.experience == expectedXP)
        #expect(summary.companionExperience == expectedXP)
        #expect(summary.rewardItems == [pendingItem])
        #expect(expectedXP > baseXP)
    }
}
