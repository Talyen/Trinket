import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleVictorySummaryTests {
    @Test func makeVictorySummaryUsesBakedAwardsAndStageBattleRewards() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        let heroProgression = CombatantProgression(level: 2, currentXP: 10, requiredXP: 155)
        let companionProgression = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let lootItem = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
            .rewardInstance(for: "chapter-1-stage-1")
        let configuration = ActiveBattleConfigurationTestSupport.make(
            runKey: BattleRunKey("journey|chapter-1-stage-1"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            heroProgression: heroProgression,
            companionProgression: companionProgression,
            stageReward: StageReward(gold: 12, itemTemplateIDs: [], materialRewards: [
                ResourceAmount(.wood, 8),
                ResourceAmount(.stone, 3),
            ]),
            rewardItems: [lootItem],
            hasProgressionRewards: true,
            musicStageID: "chapter-1-stage-1",
            heroExperienceAward: 17,
            companionExperienceAward: 9,
            materialRewards: [
                ResourceAmount(.wood, 8),
                ResourceAmount(.stone, 3),
            ]
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)

        BattleSessionTestSupport.driveUntilOutcome(session)

        let summary = try #require(session.makeVictorySummary(for: configuration))
        #expect(summary.stageGold == 12)
        #expect(summary.battleGold >= 0)
        #expect(summary.totalGold == summary.stageGold + summary.battleGold)
        #expect(summary.experience == 17)
        #expect(summary.companionExperience == 9)
        #expect(summary.heroName == hero.name)
        #expect(summary.companionName == companion.name)
        #expect(summary.heroArtworkName == hero.artReference?.thumbnailImageName)
        #expect(summary.companionArtworkName == companion.artReference?.thumbnailImageName)
        #expect(summary.rewardItems == [lootItem])
        #expect(summary.materialRewards.count == 2)
        #expect(summary.heroProgressionBefore.level == 2)
        #expect(summary.heroProgressionAfter.currentXP == 27)
        #expect(summary.companionProgressionAfter.currentXP == 9)
    }

    @Test func makeVictorySummaryUsesEachBakedPartyAward() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )

        let scaledConfiguration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 1,
            heroProgression: CombatantProgression(level: 15, currentXP: 0, requiredXP: 100),
            companionProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
            stageReward: StageReward(gold: 0, itemTemplateIDs: []),
            heroExperienceAward: 0,
            companionExperienceAward: 13
        )
        let scaledSession = BattleSession(openingHandDrawStagger: 0)
        _ = scaledSession.activate(scaledConfiguration)
        BattleSessionTestSupport.driveUntilOutcome(scaledSession)
        let scaledSummary = try #require(scaledSession.makeVictorySummary(for: scaledConfiguration))
        #expect(scaledSummary.experience == 0)
        #expect(scaledSummary.companionExperience == 13)
        #expect(scaledSummary.hasExperienceAwards == true)
        #expect(scaledSummary.rewardItems.isEmpty)
        #expect(scaledSummary.companionProgressionAfter.currentXP == 13)
    }

    @Test func makeVictorySummaryDoesNotRecomputeExperienceBonus() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        let heroProgression = CombatantProgression(level: 2, currentXP: 0, requiredXP: 155)
        let companionProgression = CombatantProgression(level: 2, currentXP: 0, requiredXP: 155)
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let pendingItem = InventoryItem(
            id: "labyrinth-audit-node",
            templateID: "audit-basic",
            baseType: baseType,
            rarity: .basic,
            displayName: "Audit Find",
            affixes: []
        )
        let configuration = ActiveBattleConfigurationTestSupport.make(
            runKey: BattleRunKey("labyrinth|audit-node"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            heroProgression: heroProgression,
            companionProgression: companionProgression,
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            rewardItems: [pendingItem],
            experienceBonusPercent: 20,
            defeatPrimaryAction: .retreat,
            hasProgressionRewards: true,
            heroExperienceAward: 42,
            companionExperienceAward: 42
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)
        BattleSessionTestSupport.driveUntilOutcome(session)

        let summary = try #require(session.makeVictorySummary(for: configuration))
        #expect(summary.experience == 42)
        #expect(summary.companionExperience == 42)
        #expect(summary.rewardItems == [pendingItem])
        #expect(configuration.experienceBonusPercent == 20)
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
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 100, itemTemplateIDs: []),
            goldFindPercent: 10
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)
        BattleSessionTestSupport.driveUntilOutcome(session)

        let summary = try #require(session.makeVictorySummary(for: configuration))
        let earnedGold = try #require(session.simulation.readModel?.earnedGold)

        let expectedTotal = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: configuration.goldFindPercent
        ).adjustedGold(100 + earnedGold)
        #expect(configuration.goldFindPercent > 0)
        #expect(summary.rawBattleEarnedGold == earnedGold)
        #expect(summary.totalGold == expectedTotal)
        // Display `battleGold` absorbs the homestead remainder; re-feeding it into
        // grant APIs would apply gold-find twice.
        #expect(summary.battleGold >= summary.rawBattleEarnedGold)
        #expect(
            HomesteadEffects(
                heroModifiers: [],
                companionModifiers: [],
                astralChanceBonusPercent: 0,
                goldFindPercent: configuration.goldFindPercent
            ).adjustedGold(100 + summary.battleGold) > expectedTotal
        )
    }
}
