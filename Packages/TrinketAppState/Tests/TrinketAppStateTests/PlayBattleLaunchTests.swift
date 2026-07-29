import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct PlayBattleLaunchTests {
    @Test func lootPackageMatchesPersistenceResolvers() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let journeyLoot = try #require(PlayBattleLaunch.lootPackage(
            for: .journey(stageID: stage.id),
            enemy: enemy,
            encounterLevel: 1
        ))
        #expect(
            journeyLoot == BattleLoot.resolveJourney(
                stage: stage,
                encounterLevel: 1,
                enemyIsBoss: false
            )
        )

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let spireLoot = try #require(PlayBattleLaunch.lootPackage(
            for: .spire(spireID: .ironVein, floor: 1)
        ))
        #expect(spireLoot == SpireCompletion.resolveLoot(for: floor))

        var labyrinth = PlayerLabyrinthState.freshStart
        labyrinth.ensureMap()
        let maybeCombatNode = labyrinth.nodes.values.first(where: \.type.isCombat)
        let combatNode = try #require(maybeCombatNode)
        let labyrinthLoot = PlayBattleLaunch.lootPackage(
            for: .labyrinth(nodeID: combatNode.id),
            labyrinth: labyrinth
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
        let encounter = try #require(PlayBattleLaunch.resolvedEncounter(for: stage))
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
        let encounter = try #require(PlayBattleLaunch.resolvedEncounter(for: stage))
        let expectedEnemyID = try #require(stage.resolvedBattleEnemyID)

        #expect(encounter.combatant.id == expectedEnemyID)
        #expect(GameContent.enemy(matching: expectedEnemyID)?.isBoss == false)
        #expect(stage.encounter.isCombat)
        #expect(stage.encounter.battleEnemyID == nil)
        #expect(stage.encounterCombatantArtReference != nil)
        #expect(stage.encounterSubjectName == (GameContent.enemy(matching: expectedEnemyID)?.name ?? "Battle"))

        let again = try #require(PlayBattleLaunch.resolvedEncounter(for: stage))
        #expect(again.combatant.id == encounter.combatant.id)
    }

    @Test func stageRewardsAlreadyClaimedResolvesJourneyPolicyOnly() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        var journey = JourneyProgressState.initial
        #expect(
            !(PlayBattleLaunch.stageRewardsAlreadyClaimed(
                resumeToken: .journey(stageID: stage.id),
                journey: journey
            ))
        )
        journey.markRewardsClaimed(for: stage)
        #expect(
            PlayBattleLaunch.stageRewardsAlreadyClaimed(
                resumeToken: .journey(stageID: stage.id),
                journey: journey
            )
        )
        #expect(
            !(PlayBattleLaunch.stageRewardsAlreadyClaimed(
                resumeToken: .spire(spireID: .ironVein, floor: 1),
                journey: journey
            ))
        )
    }
}
