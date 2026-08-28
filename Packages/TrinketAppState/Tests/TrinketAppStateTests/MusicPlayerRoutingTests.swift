import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
@testable import TrinketAppState

@MainActor
struct MusicPlayerRoutingTests {
    @Test func menuRoutePlaysMenuTrackWhenNoEncounterIsActive() throws {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .menu)
        #expect(request.resumeKey.contextKind == .menu)
    }

    @Test(arguments: [
        (
            enemyID: "skeleton",
            expectedTrackKind: MusicTrackKind.battle,
            expectedContext: MusicTrackKind.battle,
            expectedTrackID: nil as String?
        ),
        (enemyID: "the_blight_treant", expectedTrackKind: .boss, expectedContext: .boss, expectedTrackID: "boss_blight_treant"),
    ])
    func activeBattlePlaysExpectedTrack(
        enemyID: String,
        expectedTrackKind: MusicTrackKind,
        expectedContext: MusicTrackKind,
        expectedTrackID: String?
    ) throws {
        let stageID = enemyID == "skeleton" ? "chapter-1-stage-1" : "chapter-1-stage-10"
        let battle = try PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: stageID),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: GameContent.enemy(matching: enemyID)?.combatant
        )

        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: battle,
            battleStageID: stageID,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == expectedTrackKind)
        #expect(request.resumeKey.contextKind == expectedContext)
        if let expectedTrackID {
            #expect(request.track.id == expectedTrackID)
        } else {
            #expect(request.resumeKey.stageID == stageID)
            #expect(request.resumeKey.enemyID == enemyID)
        }
    }

    @Test func leavingPlayReturnsToMenuEvenWithActiveBattle() throws {
        let battle = try PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: "chapter-1-stage-10"),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: GameContent.enemy(matching: "the_blight_treant")?.combatant
        )

        let route = MusicRoute.resolve(
            selectedTab: .collection,
            activeBattle: battle,
            battleStageID: "chapter-1-stage-10",
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .menu)
        #expect(request.resumeKey.contextKind == .menu)
    }

    @Test(arguments: [
        (sceneIsActive: false, musicVolume: 0.75),
        (sceneIsActive: true, musicVolume: 0.0),
    ])
    func silencePreservesPositionWhenSceneInactiveOrMuted(sceneIsActive: Bool, musicVolume: Double) {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: nil,
            sceneIsActive: sceneIsActive,
            musicVolume: musicVolume
        )

        #expect(route == .silence(preservingPosition: true))
    }

    private func trackRequest(from route: MusicRoute) throws -> MusicPlaybackRequest {
        guard case let .track(request) = route else {
            Issue.record("Expected track route, got \(route)")
            throw MusicPlayerRoutingTestError.expectedTrack
        }
        return request
    }
}

private enum MusicPlayerRoutingTestError: Error {
    case expectedTrack
}
