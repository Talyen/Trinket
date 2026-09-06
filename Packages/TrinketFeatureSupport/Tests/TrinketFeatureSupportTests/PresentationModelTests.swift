import CoreGraphics
import SwiftUI
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketPersistence
@testable import TrinketFeatureSupport

struct PresentationModelTests {
    @Test func `item detail yield list formatting`() {
        let empty: [ResourceAmount] = []
        #expect(empty.formattedYieldList == "nothing")

        let single = [ResourceAmount(.gold, 50)]
        #expect(single.formattedYieldList == "50 Gold")

        let double = [
            ResourceAmount(.gold, 50),
            ResourceAmount(.wood, 10),
        ]
        #expect(double.formattedYieldList == "50 Gold and 10 Wood")

        let triple = [
            ResourceAmount(.gold, 50),
            ResourceAmount(.wood, 10),
            ResourceAmount(.herbs, 5),
        ]
        #expect(triple.formattedYieldList == "50 Gold, 10 Wood, and 5 Herbs")
    }

    @Test func `homestead category progress aggregates built and total tiers`() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [
                .wheatField: 2,
                .chickenCoop: 1,
            ],
        )
        let farmingProgress = HomesteadCategoryProgress(category: .farming, homestead: homestead)
        #expect(farmingProgress.builtTiers == 3)
        #expect(farmingProgress.totalTiers > 3)
        #expect(farmingProgress.subtitle == "3 / \(farmingProgress.totalTiers)")
    }

    @Test func `homestead tier copy uses stage names`() {
        #expect(HomesteadTierCopy.title(for: "Cleared Plot", nodeTitle: "Wheat Field") == "Wheat Field — Cleared Plot")
    }

    @Test func `hero header layout sizing policies and metrics`() {
        let portraitHeight = HeroHeaderLayout.HeightPolicy.portrait.height(forWidth: 300)
        #expect(portraitHeight == 400)

        let portraitMinimum = HeroHeaderLayout.HeightPolicy.portrait.height(forWidth: 100)
        #expect(portraitMinimum == HeroHeaderLayout.minimumHeaderHeight)

        let cinematicHeight = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 400)
        #expect(cinematicHeight == 312)

        let cinematicClampedMin = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 200)
        #expect(cinematicClampedMin == 288)

        let cinematicClampedMax = HeroHeaderLayout.HeightPolicy.cinematicLandscape.height(forWidth: 600)
        #expect(cinematicClampedMax == 344)
    }

    @Test func `labyrinth hex radius and destination art`() {
        let radius = LabyrinthMapPresentation.hexRadius(forAvailableWidth: 346.41016, edgePad: 0)
        #expect(radius > 0)

        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .shop) == "destination-merchant-shop")
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .rest) == nil)
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .battle) == nil)
    }

    @Test func `stage encounter and stage presentation properties`() {
        let stage = Stage(
            id: "test-stage",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 3,
            encounter: .shop,
            rewards: .empty,
        )
        #expect(stage.mapLabel == "Stage 1-3")
        #expect(stage.mapMetaLabel == "Stage 1-3 · Shop")

        #expect(abs(StageEncounter.shop.artAspectRatio - (4.0 / 3.0)) < 0.0001)
        #expect(StageEncounter.battle(enemyID: "enemy").mapTint == StageEncounter.randomBattle.mapTint)
        #expect(StageEncounter.rest.mapTint == LabyrinthMapPresentation.tint(for: .rest))
    }

    @Test func `feature contracts and contexts`() {
        let heroContext = CombatantDetailContext(kind: .hero, combatantID: "hero_paladin")
        #expect(heroContext.id == "hero-hero_paladin")

        let companionContext = CombatantDetailContext(kind: .companion, combatantID: "companion_mage")
        #expect(companionContext.id == "companion-companion_mage")

        let emptyBattleContext = BattlePresentationContext.empty
        #expect(emptyBattleContext.inventoryItems.isEmpty)
        #expect(emptyBattleContext.stageReward == nil)
        #expect(emptyBattleContext.defeatPrimaryAction == .restart)
        #expect(emptyBattleContext.goldFindPercent == 0)
        #expect(emptyBattleContext.materialRewards.isEmpty)
    }
}
