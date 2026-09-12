import CoreGraphics
import os
import SwiftUI
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence
import TrinketPersistenceTestSupport
@testable import TrinketFeatureAdapters
@testable import TrinketFeatureSupport

struct PresentationModelTests {
    #if DEBUG
    @Test @MainActor func `failed combatant edits preserve the roster and retry persists`() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "CombatantEdits")
        defer { SaveTestSupport.removeTempDirectory(directory) }
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        let hero = try #require(GameContent.hero(matching: "knight"))
        let item = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic)
        let node = try #require(CombatantTalentCatalog.configIfAvailable(for: hero.id)?.trees.first?.nodes.first)
        try playerSave.performBatchMutation { save in
            save.roster = .testSeed
            save.roster.progressions[hero.id] = .at(level: 2)
            save.roster.setEquipmentLoadout(.init(), for: hero)
            save.roster.setLoadout(save.roster.loadout(for: hero).selecting(.bash), for: hero)
            save.roster.setUnlockedTalents([node.id], for: hero)
            save.inventory.items = [item]
        }
        let commands: [CombatantDetailEdit] = [.selectAbility(.slash), .equipItem(item, .weapon), .unequipItem(.weapon), .resetTalents]
        for command in commands {
            let before = playerSave.roster
            playerSave.forcesNextSaveFailure = true
            #expect(!command.apply(to: playerSave, for: hero))
            #expect(playerSave.roster == before)
            #expect(command.apply(to: playerSave, for: hero))
            let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: directory)
            #expect(reloaded.roster == playerSave.roster)
            switch command {
            case .selectAbility:
                #expect(reloaded.roster.loadout(for: hero).basic?.id == Ability.slash.id)
            case .equipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == item.id)
            case .unequipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == nil)
            case .resetTalents:
                #expect(reloaded.roster.unlockedTalents(for: hero).isEmpty)
            }
        }
    }
    #endif

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
        #expect(LabyrinthMapPresentation.destinationEncounterArtID(for: .mystery) == nil)
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

    @Test func `frame pacing signpost support event logging`() {
        let log = OSLog(subsystem: FramePacingSignpostSupport.subsystem, category: "Test")
        FramePacingSignpostSupport.event(log: log, name: "test_event", detail: "test_detail")
        #expect(FramePacingSignpostSupport.subsystem == "com.trinket.framepacing")
    }

    @Test func `homestead effect line display formatting`() {
        let tier = HomesteadNodeTier(
            tier: 1,
            stageName: "T1",
            cost: [],
            bonus: .init(title: "Bonus", description: "Desc"),
            combatBonus: .init(
                heroModifiers: [
                    .maximumHealth(10),
                    .damageTakenPercent(.physical, 0.15),
                ],
                astralChanceBonusPercent: 5,
                goldFindPercent: 10,
            ),
            production: .init(.wood, 25),
        )
        let lines = HomesteadEffectLine.lines(for: tier)
        let healthLine = lines.first(where: { $0.label == "Health" })
        #expect(healthLine?.displayValue == "+10")

        let damageTakenLine = lines.first(where: { $0.label == "Physical damage taken" })
        #expect(damageTakenLine?.displayValue == "−15%")

        let astralLine = lines.first(where: { $0.id == .astralFind })
        #expect(astralLine?.displayValue == "+5%")

        let productionLine = lines.first(where: { $0.id == .production(.wood) })
        #expect(productionLine?.displayValue == "25")
    }

    @Test func `accessibility id full game and contracts mode presence`() {
        #expect(AccessibilityID.FullGame.offer == "Full Game Offer")
        #expect(AccessibilityID.Play.contractsModeCard == "Contracts Mode Card")
    }
}
