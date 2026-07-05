import TrinketContent
import XCTest
@testable import Trinket

final class MusicPlayerRoutingTests: XCTestCase {
    func testMenuRoutePlaysMenuTrackWhenNoEncounterIsActive() throws {
        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: nil,
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .menu)
        XCTAssertEqual(request.resumeKey.contextKind, .menu)
    }

    func testNormalBattlePreviewPlaysBattleTrack() throws {
        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .battle)
        XCTAssertEqual(request.resumeKey.contextKind, .battle)
        XCTAssertEqual(request.resumeKey.stageID, "chapter-1-stage-1")
        XCTAssertEqual(request.resumeKey.enemyID, "skeleton")
    }

    func testBossBattlePreviewPlaysBossTrack() throws {
        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-10", enemyID: "the_blight_treant"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .boss)
        XCTAssertEqual(request.track.id, "boss_blight_treant")
        XCTAssertEqual(request.resumeKey.contextKind, .boss)
    }

    func testActiveBattleTakesPriorityOverPreview() throws {
        let battle = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-1",
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "skeleton")?.combatant
        )

        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-10", enemyID: "the_blight_treant"),
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .battle)
        XCTAssertEqual(request.resumeKey.enemyID, "skeleton")
    }

    func testLeavingPlayReturnsToMenuEvenWithActiveBattle() throws {
        let battle = ActiveBattleConfigurationTestSupport.make(
            stageID: "chapter-1-stage-10",
            rngSeed: 0,
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "the_blight_treant")?.combatant
        )

        let route = MusicPlayer.route(
            selectedTab: .collection,
            preview: nil,
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .menu)
        XCTAssertEqual(request.resumeKey.contextKind, .menu)
    }

    func testInactiveSceneSilencesAndPreservesPosition() {
        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: false,
            musicVolume: 0.75
        )

        XCTAssertEqual(route, .silence(preservingPosition: true))
    }

    func testMutedMusicSilencesAndPreservesPosition() {
        let route = MusicPlayer.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "skeleton"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0
        )

        XCTAssertEqual(route, .silence(preservingPosition: true))
    }

    private func trackRequest(from route: MusicRoute) throws -> MusicPlaybackRequest {
        guard case let .track(request) = route else {
            XCTFail("Expected track route, got \(route)")
            throw MusicPlayerRoutingTestError.expectedTrack
        }
        return request
    }
}

private enum MusicPlayerRoutingTestError: Error {
    case expectedTrack
}
