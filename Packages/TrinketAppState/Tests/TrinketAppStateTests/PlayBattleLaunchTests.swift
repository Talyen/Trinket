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
    @Test func modeOwnersResolveLootWithPersistenceFormulas() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        let journeyLoot = try #require(JourneyPlayMode.resolveBattleLoot(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false
        ))
        #expect(
            journeyLoot == BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: 1,
                enemyIsBoss: false
            )
        )

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let spireLoot = try #require(SpiresPlayMode.resolveBattleLoot(for: floor))
        #expect(spireLoot == SpireCompletion.resolveLoot(for: floor))

        var labyrinth = PlayerLabyrinthState.freshStart
        labyrinth.ensureMap()
        let maybeCombatNode = labyrinth.nodes.values.first(where: \.type.isCombat)
        let combatNode = try #require(maybeCombatNode)
        let labyrinthLoot = LabyrinthPlayMode.resolveBattleLoot(
            for: combatNode,
            effects: labyrinth.effects(for: combatNode.id),
            worldSeed: labyrinth.worldSeed
        )
        #expect(
            labyrinthLoot == LabyrinthCompletion.resolveCombatLoot(
                for: combatNode,
                effects: labyrinth.effects(for: combatNode.id),
                worldSeed: labyrinth.worldSeed
            )
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

    @Test func stageRewardsAlreadyClaimedResolvesInJourneyOwner() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        var journey = JourneyProgressState.initial
        #expect(
            !(JourneyPlayMode.stageRewardsAlreadyClaimed(for: stage, journey: journey))
        )
        journey.markRewardsClaimed(for: stage)
        #expect(
            JourneyPlayMode.stageRewardsAlreadyClaimed(for: stage, journey: journey)
        )
    }

    @Test func assembleResolvesEnemyTraitModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))

        let configuration = PlayBattleLaunch.assembleConfiguration(
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            rosterState: .initial,
            inventoryState: .initial,
            enemy: skeleton.combatant
        )

        #expect(configuration.enemyModifiers.damageTakenVulnerability(for: .holy) > 0)
        #expect(configuration.enemyModifiers.damageTakenReduction(for: .bleed) > 0)
    }

    @Test func assembleAppliesUniversalDamageModifierToEveryCombatant() throws {
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let modifier = AffixModifier.damageDealt(.burn, 1)

        let launch = PlayBattleLaunch.assembleLaunch(
            rngSeed: 0,
            hero: hero,
            companion: companion,
            rosterState: .initial,
            inventoryState: .initial,
            enemy: enemy,
            universalModifiers: [modifier]
        )

        let configuration = launch.configuration
        #expect(launch.universalModifiers == [modifier])
        #expect(configuration.hero.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.companion.modifiers.damageDealtBonus(for: .burn) == 1)
        #expect(configuration.enemyModifiers.damageDealtBonus(for: .burn) == 1)
    }

    @Test func assembleBakesGoldFindAndClaimedStagePolicy() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2])

        let launch = PlayBattleLaunch.assembleLaunch(
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            rosterState: .initial,
            inventoryState: .initial,
            homesteadState: homestead,
            enemy: enemy,
            stageRewardsAlreadyClaimed: true,
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

        let configuration = PlayBattleLaunch.assembleConfiguration(
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            rosterState: .initial,
            inventoryState: .initial,
            enemy: scaledEnemy,
            enemyEncounterLevel: expectedLevel,
            hasProgressionRewards: true,
            musicStageID: stage.id
        )

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
            rngSeed: 0,
            hero: knight,
            companion: wolf,
            rosterState: .initial,
            inventoryState: .initial,
            enemyEncounterLevel: 2,
            stageReward: stageReward,
            hasProgressionRewards: true
        )

        #expect(launch.presentation.heroExperienceAward > 0)
        #expect(launch.presentation.companionExperienceAward > 0)
        #expect(launch.presentation.materialRewards == stageReward.materialRewards)
    }
}
