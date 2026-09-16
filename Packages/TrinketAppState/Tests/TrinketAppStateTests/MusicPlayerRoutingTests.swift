import Foundation
import Testing
import TrinketContent
@testable import TrinketAppState

@MainActor
struct MusicPlayerRoutingTests {
    @Test func `menu route plays menu track when no encounter is active`() throws {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: nil,
            sceneIsActive: true,
            musicVolume: 0.75,
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
            expectedTrackID: nil as String?,
        ),
        (enemyID: "the_blight_treant", expectedTrackKind: .boss, expectedContext: .boss, expectedTrackID: "boss_blight_treant"),
    ])
    func `active battle plays expected track`(
        enemyID: String,
        expectedTrackKind: MusicTrackKind,
        expectedContext: MusicTrackKind,
        expectedTrackID: String?,
    ) throws {
        let stageID = enemyID == "skeleton" ? "chapter-1-stage-1" : "chapter-1-stage-10"
        let battle = PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: stageID),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: GameContent.enemy(matching: enemyID)?.combatant,
        )

        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75,
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == expectedTrackKind)
        #expect(request.resumeKey.contextKind == expectedContext)
        if let expectedTrackID {
            #expect(request.track.id == expectedTrackID)
        } else {
            #expect(request.resumeKey.stageID == nil)
            #expect(request.resumeKey.enemyID == enemyID)
        }
    }

    @Test func `non boss battle track is stable across modes`() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton")?.combatant)
        let journeyBattle = PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: "chapter-1-stage-1"),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: enemy,
        )
        let spireBattle = PlayBattleLaunchTestSupport.make(
            origin: .spire(spireID: .ironVein, floor: 1),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: enemy,
        )

        let journeyRequest = try trackRequest(from: MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: journeyBattle,
            sceneIsActive: true,
            musicVolume: 0.75,
        ))
        let spireRequest = try trackRequest(from: MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: spireBattle,
            sceneIsActive: true,
            musicVolume: 0.75,
        ))

        #expect(journeyRequest.track.kind == .battle)
        #expect(spireRequest.track.id == journeyRequest.track.id)
    }

    @Test func `leaving play returns to menu even with active battle`() throws {
        let battle = PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: "chapter-1-stage-10"),
            rngSeed: 0,
            hero: GameContent.heroes[0],
            companion: GameContent.companions[0],
            enemy: GameContent.enemy(matching: "the_blight_treant")?.combatant,
        )

        let route = MusicRoute.resolve(
            selectedTab: .collection,
            activeBattle: battle,
            sceneIsActive: true,
            musicVolume: 0.75,
        )

        let request = try trackRequest(from: route)
        #expect(request.track.kind == .menu)
        #expect(request.resumeKey.contextKind == .menu)
    }

    @Test(arguments: [
        (sceneIsActive: false, musicVolume: 0.75),
        (sceneIsActive: true, musicVolume: 0.0),
    ])
    func `silence preserves position when scene inactive or muted`(sceneIsActive: Bool, musicVolume: Double) {
        let route = MusicRoute.resolve(
            selectedTab: .play,
            activeBattle: nil,
            sceneIsActive: sceneIsActive,
            musicVolume: musicVolume,
        )

        #expect(route == .silence(preservingPosition: true))
    }

    @Test func `menu track is stable within a day and rotates across days`() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12)))

        func menuTrackID(at date: Date) throws -> String {
            let route = MusicRoute.resolve(
                selectedTab: .collection,
                activeBattle: nil,
                sceneIsActive: true,
                musicVolume: 0.75,
                currentDate: date,
            )
            return try trackRequest(from: route).track.id
        }

        let first = try menuTrackID(at: day)
        let second = try menuTrackID(at: day)
        #expect(first == second)
        let ids = try Set((0 ..< 60).map { offset in
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: day))
            return try menuTrackID(at: date)
        })
        #expect(ids.count > 1)
        #expect(ids.isSubset(of: Set(MusicCatalog.menuTrackIDs)))
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
