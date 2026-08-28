import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleVictorySummaryTests {
    @Test func launchPreviewPresentsVictoryFromAnActivatedConfiguration() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: []),
            heroExperienceAward: 17,
            companionExperienceAward: 9
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration, presentation: context)

        session.presentLaunchVictory()

        #expect(session.spectacle.isShowingVictory)
        let summary = try #require(session.spectacle.victorySummary)
        #expect(summary.experience == 17)
        #expect(summary.companionExperience == 9)
        #expect(summary.stageGold == 12)
    }

    @Test func restartWithoutPresentationClearsPriorContext() {
        let party = BattlePartyFixtures.quickWinParty()
        let first = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(first.configuration, presentation: first.presentation)
        #expect(session.presentationContext?.stageRewardsAlreadyClaimed == true)

        let second = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed &+ 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        _ = session.restart(second.configuration)
        #expect(session.presentationContext == nil)
    }

    enum BakedVictoryAwardCase: String, CaseIterable, Sendable {
        case stageRewardsAndLoot
        case companionOnlyAward
        case bakedAwardsIgnoreExperienceBonus
    }

    @Test(arguments: BakedVictoryAwardCase.allCases)
    func makeVictorySummaryUsesBakedAwards(_ awardCase: BakedVictoryAwardCase) throws {
        switch awardCase {
        case .stageRewardsAndLoot:
            try assertStageRewardsAndLootSummary()
        case .companionOnlyAward:
            try assertCompanionOnlyAwardSummary()
        case .bakedAwardsIgnoreExperienceBonus:
            try assertBakedAwardsIgnoreExperienceBonus()
        }
    }

    private func knightWolfEnemy() throws -> (Combatant, Combatant, Combatant) {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: []
        )
        return (hero, companion, enemy)
    }

    private func assertStageRewardsAndLootSummary() throws {
        let (hero, companion, enemy) = try knightWolfEnemy()
        let lootItem = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
            .rewardInstance(for: "chapter-1-stage-1")
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("journey|chapter-1-stage-1"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            heroProgression: CombatantProgression(level: 2, currentXP: 1, requiredXP: 15),
            companionProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
            stageReward: StageReward(gold: 12, itemTemplateIDs: [], materialRewards: [
                ResourceAmount(.wood, 8),
                ResourceAmount(.stone, 3),
            ]),
            rewardItems: [lootItem],
            hasProgressionRewards: true,
            musicStageID: "chapter-1-stage-1",
            heroExperienceAward: 2,
            companionExperienceAward: 1,
            materialRewards: [
                ResourceAmount(.wood, 8),
                ResourceAmount(.stone, 3),
            ]
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.stageGold == 12)
        #expect(summary.battleGold >= 0)
        #expect(summary.totalGold == summary.stageGold + summary.battleGold)
        #expect(summary.experience == 2)
        #expect(summary.companionExperience == 1)
        #expect(summary.heroName == hero.name)
        #expect(summary.companionName == companion.name)
        #expect(summary.heroArtworkName == hero.artReference?.thumbnailImageName)
        #expect(summary.companionArtworkName == companion.artReference?.thumbnailImageName)
        #expect(summary.rewardItems == [lootItem])
        #expect(summary.materialRewards.count == 2)
        #expect(summary.heroProgressionBefore.level == 2)
        #expect(summary.heroProgressionAfter.currentXP == 3)
        #expect(summary.companionProgressionAfter.currentXP == 1)
    }

    private func assertCompanionOnlyAwardSummary() throws {
        let (hero, companion, enemy) = try knightWolfEnemy()
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 1,
            heroProgression: CombatantProgression(level: 15, currentXP: 0, requiredXP: CombatantProgression.requiredXP(forLevel: 15)),
            companionProgression: CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
            stageReward: StageReward(gold: 0, itemTemplateIDs: []),
            heroExperienceAward: 0,
            companionExperienceAward: 2
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.experience == 0)
        #expect(summary.companionExperience == 2)
        #expect(summary.hasExperienceAwards == true)
        #expect(summary.rewardItems.isEmpty)
        #expect(summary.companionProgressionAfter.currentXP == 2)
    }

    private func assertBakedAwardsIgnoreExperienceBonus() throws {
        let (hero, companion, enemy) = try knightWolfEnemy()
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let pendingItem = InventoryItem(
            id: "labyrinth-audit-node",
            templateID: "audit-basic",
            baseType: baseType,
            rarity: .basic,
            displayName: "Audit Find",
            affixes: []
        )
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("labyrinth|audit-node"),
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEncounterLevel: 2,
            heroProgression: CombatantProgression(level: 2, currentXP: 0, requiredXP: 15),
            companionProgression: CombatantProgression(level: 2, currentXP: 0, requiredXP: 15),
            stageReward: StageReward(gold: 10, itemTemplateIDs: []),
            rewardItems: [pendingItem],
            experienceBonusPercent: 20,
            defeatPrimaryAction: .retreat,
            hasProgressionRewards: true,
            heroExperienceAward: 4,
            companionExperienceAward: 4
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.experience == 4)
        #expect(summary.companionExperience == 4)
        #expect(summary.rewardItems == [pendingItem])
        #expect(context.experienceBonusPercent == 20)
    }

    private func makeDrivenVictorySummary(
        configuration: BattleRunConfiguration,
        context: BattlePresentationContext
    ) throws -> BattleVictorySummary {
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)
        session.installPresentationContext(context)
        BattleSessionTestSupport.driveUntilOutcome(session)
        return try #require(session.makeVictorySummary(for: configuration, presentation: context))
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
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 100, itemTemplateIDs: []),
            goldFindPercent: 10
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)
        session.installPresentationContext(context)
        BattleSessionTestSupport.driveUntilOutcome(session)

        let summary = try #require(session.makeVictorySummary(for: configuration, presentation: context))
        let earnedGold = try #require(session.earnedGold)

        let expectedTotal = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: context.goldFindPercent
        ).adjustedGold(100 + earnedGold)
        #expect(context.goldFindPercent > 0)
        #expect(summary.rawBattleEarnedGold == earnedGold)
        #expect(summary.totalGold == expectedTotal)
        #expect(summary.battleGold >= summary.rawBattleEarnedGold)
        #expect(
            HomesteadEffects(
                heroModifiers: [],
                companionModifiers: [],
                astralChanceBonusPercent: 0,
                goldFindPercent: context.goldFindPercent
            ).adjustedGold(100 + summary.battleGold) > expectedTotal
        )
    }
}
