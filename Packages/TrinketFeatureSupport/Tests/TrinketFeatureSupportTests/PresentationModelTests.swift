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
    @Test func itemDetailYieldListFormatting() {
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

    @Test func homesteadCategoryProgressAggregatesBuiltAndTotalTiers() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [
                .wheatField: 2,
                .chickenCoop: 1,
            ]
        )
        let farmingProgress = HomesteadCategoryProgress(category: .farming, homestead: homestead)
        #expect(farmingProgress.builtTiers == 3)
        #expect(farmingProgress.totalTiers > 3)
        #expect(farmingProgress.subtitle == "3 / \(farmingProgress.totalTiers)")
    }

    @Test func homesteadTierCopyFormatsRomanNumerals() {
        #expect(HomesteadTierCopy.title(for: 1, nodeTitle: "Node") == "Node I")
        #expect(HomesteadTierCopy.title(for: 2, nodeTitle: "Node") == "Node II")
        #expect(HomesteadTierCopy.title(for: 3, nodeTitle: "Node") == "Node III")
        #expect(HomesteadTierCopy.title(for: 4, nodeTitle: "Node") == "Node IV")
        #expect(HomesteadTierCopy.title(for: 5, nodeTitle: "Node") == "Node 5")
    }

    @Test func heroHeaderLayoutSizingPoliciesAndMetrics() {
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

        #expect(HeroHeaderLayout.scrimHeight == 140.0)

        let normalOverscroll = HeroHeaderLayout.overscroll(contentOffsetY: -20, topInset: 0)
        #expect(normalOverscroll == 20)

        let noOverscroll = HeroHeaderLayout.overscroll(contentOffsetY: 50, topInset: 0)
        #expect(noOverscroll == 0)

        let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: 300, overscroll: 25)
        #expect(metrics.height == 325)
        #expect(metrics.offsetY == -25)
    }

    @Test func labyrinthHexRadiusAndDestinationArt() {
        let radius = LabyrinthMapPresentation.hexRadius(forAvailableWidth: 346.41016, edgePad: 0)
        #expect(radius > 0)

        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .shop) == "destination-merchant-shop")
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .rest) == "destination-campfire")
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .battle) == nil)
    }

    @Test func stageEncounterAndStagePresentationProperties() {
        let stage = Stage(
            id: "test-stage",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 3,
            encounter: .shop,
            rewards: .empty
        )
        #expect(stage.mapLabel == "Stage 1-3")
        #expect(stage.mapMetaLabel == "Stage 1-3 · Shop")

        #expect(abs(StageEncounter.shop.artAspectRatio - (4.0 / 3.0)) < 0.0001)
        #expect(StageEncounter.battle(enemyID: "enemy").mapTint == StageEncounter.randomBattle.mapTint)
    }

    @Test func featureContractsAndContexts() {
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
