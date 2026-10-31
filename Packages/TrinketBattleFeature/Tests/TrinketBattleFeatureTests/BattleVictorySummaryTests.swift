import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleVictorySummaryTests {
    @Test func `launch preview presents victory from an activated configuration`() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: []),
            heroExperienceAward: 17,
            companionExperienceAward: 9,
        )
        let session = BattleSession()
        _ = session.activate(configuration, presentation: context)

        session.presentLaunchVictory()

        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        let summary = try #require(session.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(summary.settlement.award.heroExperience == 17)
        #expect(summary.settlement.award.companionExperience == 9)
        #expect(summary.settlement.award.stageGold == 12)
    }

    @Test func `restart without presentation clears prior rewards`() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let first = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageReward: StageReward(gold: 12, itemTemplateIDs: []),
            heroExperienceAward: 17,
            companionExperienceAward: 9,
        )
        let session = BattleSession()
        _ = session.activate(first.configuration, presentation: first.presentation)
        session.presentLaunchVictory()
        let original = try #require(session.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(original.settlement.award.stageGold == 12)
        #expect(original.settlement.award.heroExperience == 17)
        #expect(original.settlement.award.companionExperience == 9)

        let second = BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeedVariant(1),
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )
        #expect(session.restart(second.configuration))
        session.presentLaunchVictory()
        let restarted = try #require(session.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(restarted.settlement.award.stageGold == 0)
        #expect(restarted.settlement.award.heroExperience == 0)
        #expect(restarted.settlement.award.companionExperience == 0)
    }

    enum BakedVictoryAwardCase: String, CaseIterable {
        case stageRewardsAndLoot
        case companionOnlyAward
        case bakedAwardsIgnoreExperienceBonus
    }

    @Test(arguments: BakedVictoryAwardCase.allCases)
    func `make victory summary uses baked awards`(_ awardCase: BakedVictoryAwardCase) throws {
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
            abilities: [],
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
            ],
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.settlement.award.stageGold == 12)
        #expect(summary.settlement.award.battleGold == summary.settlement.award.goldFlow.net)
        #expect(summary.settlement.award.goldDelta == 12 + summary.settlement.award.goldFlow.net)
        #expect(summary.settlement.award.heroExperience == 2)
        #expect(summary.settlement.award.companionExperience == 1)
        #expect(summary.heroName == hero.name)
        #expect(summary.companionName == companion.name)
        #expect(summary.heroArtworkName == hero.artReference?.thumbnailImageName)
        #expect(summary.companionArtworkName == companion.artReference?.thumbnailImageName)
        #expect(summary.settlement.award.items == [lootItem])
        #expect(summary.settlement.award.materials.count == 2)
        #expect(summary.settlement.inputs.heroProgression.level == 2)
        #expect(summary.settlement.heroProgressionAfter.currentXP == 3)
        #expect(summary.settlement.companionProgressionAfter.currentXP == 1)
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
            companionExperienceAward: 2,
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.settlement.award.heroExperience == 0)
        #expect(summary.settlement.award.companionExperience == 2)
        #expect(summary.hasExperienceAwards == true)
        #expect(summary.settlement.award.items.isEmpty)
        #expect(summary.settlement.companionProgressionAfter.currentXP == 2)
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
            affixes: [],
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
            hasProgressionRewards: true,
            heroExperienceAward: 4,
            companionExperienceAward: 4,
        )
        let summary = try makeDrivenVictorySummary(configuration: configuration, context: context)
        #expect(summary.settlement.award.heroExperience == 4)
        #expect(summary.settlement.award.companionExperience == 4)
        #expect(summary.settlement.award.items == [pendingItem])
    }

    private func makeDrivenVictorySummary(
        configuration: BattleRunConfiguration,
        context: BattlePresentationContext,
    ) throws -> BattleVictorySummary {
        try #require(
            BattleSessionTestSupport.makeDrivenVictorySummary(
                configuration: configuration,
                presentation: context,
            ),
        )
    }

    @Test func `make victory summary keeps raw battle gold separate from homestead display split`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash],
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 1,
            abilities: [],
        )
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageReward: StageReward(gold: 100, itemTemplateIDs: []),
            goldFindPercent: 10,
        )
        let session = BattleSession()
        _ = session.activate(configuration, presentation: context)
        BattleSessionTestSupport.driveUntilOutcome(session)

        let summary = try #require(session.makeVictorySummary(for: configuration, presentation: context))
        let earnedGold = try #require(session.goldFlow?.net)

        let expectedTotal = HomesteadEffects(
            heroModifiers: [],
            companionModifiers: [],
            astralChanceBonusPercent: 0,
            goldFindPercent: context.rewardPlan.goldFindPercent,
        ).adjustedGold(100 + earnedGold)
        #expect(context.rewardPlan.goldFindPercent > 0)
        #expect(summary.settlement.award.goldFlow.net == earnedGold)
        #expect(summary.settlement.award.goldDelta == expectedTotal)
        #expect(summary.settlement.award.battleGold == expectedTotal - 100)
        #expect(
            HomesteadEffects(
                heroModifiers: [],
                companionModifiers: [],
                astralChanceBonusPercent: 0,
                goldFindPercent: context.rewardPlan.goldFindPercent,
            ).adjustedGold(100 + summary.settlement.award.battleGold) > expectedTotal,
        )
    }
}
