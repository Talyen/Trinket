import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleVictorySummaryTests {
    @Test func makeVictorySummaryIncludesStageBattleRewardsAndLevelScaledXP() throws {
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
        let lootItem = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
            .rewardInstance(for: "chapter-1-stage-1")
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: "chapter-1-stage-1"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            roster: rosterState,
            stageReward: StageReward(gold: 12, itemTemplateIDs: [], materialRewards: [
                ResourceAmount(.wood, 8),
                ResourceAmount(.stone, 3),
            ]),
            pendingRewardItem: lootItem
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        session.activeBattle = configuration

        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = try BattleVictorySummary.make(
            configuration: configuration,
            state: state
        )
        let expectedHeroXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedCompanionXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 2)

        #expect(summary.stageGold == 12)
        #expect(summary.battleGold >= 0)
        #expect(summary.totalGold == summary.stageGold + summary.battleGold)
        #expect(summary.experience == expectedHeroXP)
        #expect(summary.heroName == hero.name)
        #expect(summary.companionName == companion.name)
        #expect(summary.heroArtworkName == hero.artReference?.thumbnailImageName)
        #expect(summary.companionArtworkName == companion.artReference?.thumbnailImageName)
        #expect(summary.rewardItems.map(\.displayName) == ["Shortsword"])
        #expect(summary.rewardItems.first?.id == "chapter-1-stage-1-shortsword-basic")
        #expect(summary.rewardItems.first?.affixes.isEmpty == false)
        #expect(summary.materialRewards.count == 2)
        #expect(summary.heroProgressionBefore.level == 2)
        #expect(summary.heroProgressionAfter.currentXP == 10 + expectedHeroXP)
        #expect(summary.companionProgressionAfter.currentXP == expectedCompanionXP)
    }

    @Test func makeVictorySummaryScalesExperienceByCombatantLevel() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )

        var scaledRoster = PlayerRosterState.freshStart
        scaledRoster.progressions[hero.id] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        scaledRoster.progressions[companion.id] = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let scaledConfiguration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 1,
            roster: scaledRoster,
            stageReward: StageReward(gold: 0, itemTemplateIDs: [])
        )
        let scaledSession = BattleSession(openingHandDrawStagger: 0)
        scaledSession.activeBattle = scaledConfiguration
        BattleSessionTestSupport.driveUntilOutcome(scaledSession)
        let scaledState = try #require(scaledSession.state)
        let scaledSummary = try BattleVictorySummary.make(
            configuration: scaledConfiguration,
            state: scaledState
        )
        let expectedScaledCompanionXP = ExperienceScaling.battleAward(playerLevel: 1, enemyLevel: 1)
        #expect(scaledSummary.experience == 0)
        #expect(scaledSummary.companionExperience == expectedScaledCompanionXP)
        #expect(scaledSummary.hasExperienceAwards == true)
        #expect(scaledSummary.rewardItems.isEmpty)
        #expect(scaledSummary.companionProgressionAfter.currentXP == expectedScaledCompanionXP)
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
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let pendingItem = InventoryItem(
            id: "labyrinth-audit-node",
            templateID: "audit-basic",
            baseType: baseType,
            rarity: .basic,
            displayName: "Audit Find",
            affixes: []
        )
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .labyrinth(nodeID: "audit-node"),
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
        let session = BattleSession(openingHandDrawStagger: 0)
        session.activeBattle = configuration
        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: state
        )
        let baseXP = ExperienceScaling.battleAward(playerLevel: 2, enemyLevel: 2)
        let expectedXP = StageCompletion.adjustedExperienceAward(baseXP, xpPercent: 20)

        #expect(summary.experience == expectedXP)
        #expect(summary.companionExperience == expectedXP)
        #expect(summary.rewardItems == [pendingItem])
        #expect(expectedXP > baseXP)
    }

    @Test func makeVictorySummaryKeepsRawBattleGoldSeparateFromHomesteadDisplaySplit() throws {
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
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2])
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            homestead: homestead,
            stageReward: StageReward(gold: 100, itemTemplateIDs: [])
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        session.activeBattle = configuration
        BattleSessionTestSupport.driveUntilOutcome(session)

        let state = try #require(session.state)
        let summary = BattleVictorySummary.make(
            configuration: configuration,
            state: state
        )

        let expectedTotal = StageCompletion.resolvedGoldReward(
            stageGold: 100,
            battleEarnedGold: state.earnedGold,
            goldFindPercent: configuration.goldFindPercent
        )
        #expect(configuration.goldFindPercent > 0)
        #expect(summary.rawBattleEarnedGold == state.earnedGold)
        #expect(summary.totalGold == expectedTotal)
        // Display `battleGold` absorbs the homestead remainder; re-feeding it into
        // grant APIs would apply gold-find twice.
        #expect(summary.battleGold >= summary.rawBattleEarnedGold)
        #expect(
            StageCompletion.resolvedGoldReward(
                stageGold: 100,
                battleEarnedGold: summary.battleGold,
                goldFindPercent: configuration.goldFindPercent
            ) > expectedTotal
        )
    }
}
