import Foundation
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@Suite(.serialized)
@MainActor
struct PlaythroughLifecycleTests {
    @Test func `defeat retry leave and retreat preserve the encounter`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughDefeat")
        defer { SaveTestSupport.removeTempDirectory(output) }
        let career = try PlaythroughCareer(scenario: .init(), output: output)
        defer { career.close() }
        try await career.perform(.starterHero("knight"))
        try await career.perform(.starterCompanion("wolf"))
        try await career.perform(.campaign("chapter-1-stage-1", 123))
        let original = try #require(career.battle.activeBattle)
        for _ in 0 ..< 100 where career.battle.outcome == nil {
            try await career.perform(.endTurn)
        }
        #expect(career.battle.outcome == .defeat)
        try await career.perform(.defeat(retry: true))
        #expect(career.battle.activeBattle?.id != original.id)
        #expect(career.store.journey.completedStageIDs.isEmpty)
        let afterClaim = career.snapshot
        #expect(!career.play.completeActiveBattle(original, battleGold: .init()).didComplete)
        #expect(career.snapshot == afterClaim)
        try await career.perform(.retreat)
        #expect(career.snapshot == afterClaim)
        try await career.perform(.reopen)
        try await career.perform(.campaign("chapter-1-stage-1", 124))
        for _ in 0 ..< 100 where career.battle.outcome == nil {
            try await career.perform(.endTurn)
        }
        try await career.perform(.defeat(retry: false))
        try await career.perform(.reopen)
        #expect(career.store.journey.completedStageIDs.isEmpty)
        #expect(career.store.journey.activeStageID == "chapter-1-stage-1")
    }

    @Test(arguments: [false, true])
    func `earned victory survives write failure and rejects duplicate claim`(primaryOnly: Bool) async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughFailure")
        defer { SaveTestSupport.removeTempDirectory(output) }
        let career = try PlaythroughCareer(scenario: .init(), output: output)
        defer { career.close() }
        try await career.perform(.starterHero("knight"))
        try await career.perform(.starterCompanion("wolf"))
        try await career.perform(.campaign("chapter-1-stage-1", 42))
        try await career.fight(settle: false)
        #expect(career.battle.outcome == .victory)
        let config = try #require(career.battle.activeBattle)
        let award = try #require(career.battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let before = career.snapshot
        if primaryOnly {
            career.store.forcesNextDatabaseSaveFailure = true
        } else {
            career.store.forcesNextSaveFailure = true
        }
        let accepted = career.battle.claimVictory(configurationID: config.id, summary: award, defersPresentationExit: false)
        #expect(accepted == primaryOnly)
        if primaryOnly {
            #expect(career.store.pendingSaveRecovery?.hasPendingSave == true)
        } else {
            #expect(career.snapshot == before)
            try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { career.store.isRetryingSaveAction }
            #expect(!career.store.isRetryingSaveAction)
        }
        let awarded = career.snapshot
        #expect(career.store.journey.completedStageIDs.contains("chapter-1-stage-1"))
        #expect(!career.battle.claimVictory(configurationID: config.id, summary: award))
        #expect(career.snapshot == awarded)
        // Deliberately do not flush: reopen must recover the last accepted write.
        career.close()
        try career.open()
        #expect(career.snapshot == awarded)
        #expect(!career.store.isPersistenceDegraded)
    }

    @Test(arguments: ["campaign", "contracts", "labyrinth", "spires"])
    func `mode careers keep earned progress across reload`(mode: String) async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughMode")
        defer { SaveTestSupport.removeTempDirectory(output) }
        var scenario = PlaythroughScenario()
        scenario.mode = mode
        scenario.fullAccess = true
        scenario.policy = "setupAware-v1"
        let career = try PlaythroughCareer(scenario: scenario, output: output)
        _ = try await career.run(reload: true)
        #expect(career.summary.termination == "completedObjective")
        #expect(career.summary.outcomes.count == 2)
    }
}
