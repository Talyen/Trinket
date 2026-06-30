import XCTest
@testable import Trinket

final class MusicDirectorTests: XCTestCase {
    private let director = MusicDirector()

    func testMenuRoutePlaysMenuTrackWhenNoEncounterIsActive() throws {
        let route = director.route(
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
        let route = director.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "goblin"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .battle)
        XCTAssertEqual(request.resumeKey.contextKind, .battle)
        XCTAssertEqual(request.resumeKey.stageID, "chapter-1-stage-1")
        XCTAssertEqual(request.resumeKey.enemyID, "goblin")
    }

    func testBossBattlePreviewPlaysBossTrack() throws {
        let route = director.route(
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
        let battle = ActiveBattleConfiguration(
            stageID: "chapter-1-stage-1",
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "goblin")?.combatant
        )

        let route = director.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-10", enemyID: "the_blight_treant"),
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75
        )

        let request = try trackRequest(from: route)
        XCTAssertEqual(request.track.kind, .battle)
        XCTAssertEqual(request.resumeKey.enemyID, "goblin")
    }

    func testLeavingPlayReturnsToMenuEvenWithActiveBattle() throws {
        let battle = ActiveBattleConfiguration(
            stageID: "chapter-1-stage-10",
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0],
            enemy: GameContent.enemy(matching: "the_blight_treant")?.combatant
        )

        let route = director.route(
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
        let route = director.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "goblin"),
            activeBattle: nil,
            sceneIsActive: false,
            musicVolume: 0.75
        )

        XCTAssertEqual(route, .silence(preservingPosition: true))
    }

    func testMutedMusicSilencesAndPreservesPosition() {
        let route = director.route(
            selectedTab: .play,
            preview: BattleMusicPreview(stageID: "chapter-1-stage-1", enemyID: "goblin"),
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0
        )

        XCTAssertEqual(route, .silence(preservingPosition: true))
    }

    private func trackRequest(from route: MusicRoute) throws -> MusicPlaybackRequest {
        guard case let .track(request) = route else {
            XCTFail("Expected track route, got \(route)")
            throw MusicDirectorTestError.expectedTrack
        }
        return request
    }
}

private enum MusicDirectorTestError: Error {
    case expectedTrack
}
