import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct PlayBattleLaunchTests {
    /// Assembles with the default empty roster/inventory state used across these tests.
    private func makeLaunch(_ input: BattleLaunchInput) -> BattleLaunchAssembly {
        PlayBattleLaunch.assembleLaunch(
            input: input,
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial
        )
    }

    @Test func resolvedJourneyEncounterScalesEnemy() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)
        let stage = try #require(battleStages.last)
        let encounter = try #require(JourneyPlayMode.resolvedEncounter(for: stage))
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        #expect(encounter.level == expectedLevel)
        #expect(encounter.level > 1)
        #expect(encounter.combatant.id == stage.encounter.battleEnemyID)
    }

    @Test func randomBattleResolvesDeterministicNonBossEncounter() throws {
        let stage = try #require(
            GameContent.chapters
                .flatMap(\.stages)
                .first { stage in
                    if case .randomBattle = stage.encounter {
                        return true
                    }
                    return false
                }
        )
        let encounter = try #require(JourneyPlayMode.resolvedEncounter(for: stage))
        let expectedEnemyID = try #require(stage.resolvedBattleEnemyID)

        #expect(encounter.combatant.id == expectedEnemyID)
        #expect(GameContent.enemy(matching: expectedEnemyID)?.isBoss == false)
        #expect(stage.encounter.isCombat)
        #expect(stage.encounter.battleEnemyID == nil)
        #expect(stage.encounterCombatantArtReference != nil)
        #expect(stage.encounterSubjectName == (GameContent.enemy(matching: expectedEnemyID)?.name ?? "Battle"))

        let again = try #require(JourneyPlayMode.resolvedEncounter(for: stage))
        #expect(again.combatant.id == encounter.combatant.id)
    }

    @Test func assembleResolvesEnemyTraitModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))

        let configuration = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: skeleton.combatant
            ),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial
        ).configuration

        #expect(configuration.enemyModifiers.damageTakenVulnerability(for: .holy) > 0)
        #expect(configuration.enemyModifiers.damageTakenReduction(for: .bleed) > 0)
    }

    @Test func assembleAppliesUniversalDamageModifierToEveryCombatant() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifier = AffixModifier.damageDealt(.burn, 1)

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: hero,
                companion: companion,
                enemy: enemy,
                universalModifiers: [modifier]
            ),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial
        )

        let configuration = launch.configuration
        #expect(launch.universalModifiers == [modifier])
        #expect(configuration.hero.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.companion.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.enemyModifiers.damageDealtBonus(for: .burn) == 1)
    }

    @Test func assembleCarriesLabyrinthModifiersOnPresentation() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifiers = try [
            #require(GameContent.labyrinthModifier(id: LabyrinthModifierID("ironPressure"))),
        ]

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: hero,
                companion: companion,
                enemy: enemy,
                labyrinthModifiers: modifiers
            ),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial
        )

        #expect(launch.presentation.labyrinthModifiers == modifiers)
    }

    @Test func assembleBakesGoldFindAndClaimedStagePolicy() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2])

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageRewardsAlreadyClaimed: true
            ),
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial,
            homesteadState: homestead,
            hasProgressionRewards: true,
            musicStageID: stage.id
        )

        #expect(launch.presentation.goldFindPercent == homestead.effects.goldFindPercent)
        #expect(launch.presentation.goldFindPercent > 0)
        #expect(launch.presentation.stageRewardsAlreadyClaimed)
    }

    @Test func assemblePreservesPreScaledEnemyStats() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)
        let stage = try #require(battleStages.last)
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        #expect(expectedLevel > 1)

        let enemyID = try #require(stage.resolvedBattleEnemyID)
        let catalogEnemy = try #require(GameContent.enemy(matching: enemyID))
        let scaledEnemy = CombatantLevelScaler.scale(enemy: catalogEnemy, level: expectedLevel)

        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })

        let configuration = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: scaledEnemy,
                enemyEncounterLevel: expectedLevel
            ),
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial,
            hasProgressionRewards: true,
            musicStageID: stage.id
        ).configuration

        let enemy = try #require(configuration.enemy)
        #expect(enemy.maxHealth == scaledEnemy.maxHealth)
        #expect(enemy.maxHealth > catalogEnemy.combatant.maxHealth)
        #expect(configuration.enemyEncounterLevel == expectedLevel)
        #expect(configuration.enemyModifiers.triggers.controlResistancePercent >= 0)
    }

    @Test func assembleBakesExperienceAndMaterialAwards() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stageReward = StageReward(
            gold: 12,
            itemTemplateIDs: [],
            materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)]
        )

        let launch = PlayBattleLaunch.assembleLaunch(
            input: BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemyEncounterLevel: 2,
                stageReward: stageReward
            ),
            rngSeed: 0,
            rosterState: .initial,
            inventoryState: .initial,
            hasProgressionRewards: true
        )

        #expect(launch.presentation.heroExperienceAward > 0)
        #expect(launch.presentation.companionExperienceAward > 0)
        #expect(launch.presentation.materialRewards == stageReward.materialRewards)
    }

    @Test func assembleResolvesRewardItemsFromPendingOrStagePolicy() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let pendingItem = InventoryItem(
            id: "pending-audit-reward",
            templateID: "shortsword-basic",
            baseType: baseType,
            rarity: .basic,
            displayName: "Pending Find",
            affixes: []
        )

        let withPending = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 10, itemTemplateIDs: ["shortsword-basic"]),
                pendingRewardItem: pendingItem
            )
        )
        #expect(withPending.presentation.rewardItems == [pendingItem])

        let noPendingNilStage = makeLaunch(
            BattleLaunchInput(hero: knight, companion: wolf, enemy: enemy)
        )
        #expect(noPendingNilStage.presentation.rewardItems.isEmpty)

        let noPendingEmptyStage = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 0, itemTemplateIDs: [])
            )
        )
        #expect(noPendingEmptyStage.presentation.rewardItems.isEmpty)

        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let fromStage = makeLaunch(
            BattleLaunchInput(
                hero: knight,
                companion: wolf,
                enemy: enemy,
                stageReward: StageReward(gold: 10, itemTemplateIDs: ["shortsword-basic"])
            )
        )
        #expect(fromStage.presentation.rewardItems == [template])
    }
}
