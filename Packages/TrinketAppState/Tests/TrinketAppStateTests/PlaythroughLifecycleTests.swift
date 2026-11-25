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
    @Test func `old equipment journals decode and new journals retain the selected secondary slot`() throws {
        let old = Data(#"{"equip":{"combatant":"knight","item":"old-item"}}"#.utf8)
        #expect(try JSONDecoder().decode(PlaythroughAction.self, from: old) == .equip(combatant: "knight", item: "old-item"))
        let action = PlaythroughAction.equipInSlot(combatant: "knight", item: "new-item", slot: .secondaryAccessory)
        #expect(try JSONDecoder().decode(PlaythroughAction.self, from: JSONEncoder().encode(action)) == action)
    }

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
        try #require(career.store.persistFixtureBatch(logging: "Winning persistence fixture") { save in
            save.homestead.nodeTiers[.wheatField] = 4
            save.homestead.nodeTiers[.chickenCoop] = 4
            save.homestead.nodeTiers[.blacksmithForge] = 4
            save.homestead.nodeTiers[.hunterLodge] = 4
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            save.roster.setLoadout(.init(basic: AbilityCatalog.slash), for: hero)
            save.roster.setLoadout(.init(basic: AbilityCatalog.rendingSlash), for: companion)
        })
        try await career.perform(.campaign("chapter-1-stage-1", 42))
        let prepared = try #require(career.battle.activeBattle)
        #expect(prepared.hero.modifiers.maximumHealthPercentBonus == 0.4)
        #expect(prepared.hero.combatant.abilityLoadout.basic?.id == AbilityCatalog.slash.id)
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
            career.state.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
            try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { career.store.isRetryingSaveAction }
            career.state.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
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

    @Test(arguments: [5, 6, 7])
    func `expansion chapters reach every stage and preserve claims through reopen`(chapterNumber: Int) async throws {
        let chapter = try #require(GameContent.chapter(id: "chapter-\(chapterNumber)"))
        let output = try SaveTestSupport.makeTempDirectory(prefix: "CampaignExpansion")
        defer { SaveTestSupport.removeTempDirectory(output) }
        var scenario = PlaythroughScenario()
        scenario.fullAccess = true
        scenario.policy = "setupAware-v1"
        let career = try PlaythroughCareer(scenario: scenario, output: output)
        defer { career.close() }
        try await career.perform(.starterHero(scenario.heroID))
        try await career.perform(.starterCompanion(scenario.companionID))
        try #require(career.store.persistFixtureBatch(logging: "Campaign expansion entry") { save in
            for finished in GameContent.chapters.prefix(chapterNumber - 1) {
                save.journey.markChapterCompleteWithoutRewards(finished.id)
            }
            // Skip the earlier chapters and use a strong party to exercise the
            // encounter and claim paths independently of balance.
            save.roster.progressions[scenario.heroID] = .at(level: 80)
            save.roster.progressions[scenario.companionID] = .at(level: 80)
            save.roster.grantGold(900)
            save.homestead = PlayerSave.unlockedAll.homestead
        })

        for stage in chapter.stages {
            try #require(career.store.journey.activeStageID == stage.id)
            try await career.enterNextEncounter()
            if let enemyID = stage.encounter.battleEnemyID {
                try #require(career.battle.activeBattle?.enemy?.id == enemyID)
                try await career.fight()
                try #require(career.summary.outcomes.last == "victory")
            }
            while try await career.resolvePendingChoice() {}
            try #require(career.store.journey.hasClaimedRewards(for: stage))
        }

        #expect(career.summary.outcomes.count == 5)
        try await career.perform(.reopen)
        #expect(chapter.stages.allSatisfy { career.store.journey.isCompleted($0) })
        #expect(chapter.stages.allSatisfy { career.store.journey.hasClaimedRewards(for: $0) })
        let nextChapter = GameContent.chapter(id: "chapter-\(chapterNumber + 1)")
        #expect(career.store.journey.activeStageID == nextChapter?.stages.first?.id)
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
