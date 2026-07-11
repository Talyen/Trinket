import Testing
import TrinketContent
@testable import Trinket

@MainActor
struct MusicPlayerRoutingTests {
    @Test func menuRoutePlaysMenuTrackWhenNoEncounterIsActive() throws {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: nil,
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .menu)
        #expect(request.resumeKey.contextKind == .menu)
    }

    @Test func normalBattlePreviewPlaysBattleTrack() throws {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .battle)
        #expect(request.resumeKey.contextKind == .battle)
        #expect(request.resumeKey.stageID == "chapter-1-stage-1")
        #expect(request.resumeKey.enemyID == "skeleton")
    }

    @Test func bossBattlePreviewPlaysBossTrack() throws {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-5", enemyID: "the_blight_treant"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .boss)
        #expect(request.track.id == "boss_blight_treant")
        #expect(request.resumeKey.contextKind == .boss)
    }

    @Test func activeBattleTakesPriorityOverPreview() throws {
        let battle = try ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "skeleton")?.combatant
        )

        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-5", enemyID: "the_blight_treant"),
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .battle)
        #expect(request.resumeKey.enemyID == "skeleton")
    }

    @Test func leavingPlayReturnsToMenuEvenWithActiveBattle() throws {
        let battle = try ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-5",
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "the_blight_treant")?.combatant
        )

        let route = MusicRoute.resolve(
            selectedTab: .collection,
            preview: nil,
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .menu)
        #expect(request.resumeKey.contextKind == .menu)
    }

    @Test func inactiveSceneSilencesAndPreservesPosition() {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: false,
            musicVolume: 0.75
        )

        #expect(route == .silence(preservingPosition: true))
    }

    @Test func mutedMusicSilencesAndPreservesPosition() {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0
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
