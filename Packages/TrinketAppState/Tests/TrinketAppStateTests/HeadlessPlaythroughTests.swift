import Foundation
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@Suite(.serialized)
@MainActor
struct HeadlessPlaythroughTests {
    @Test func `free access rejects locked content without changing earned progress`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughAccess")
        defer { SaveTestSupport.removeTempDirectory(output) }
        let career = try PlaythroughCareer(scenario: .init(), output: output)
        _ = try await career.run(reload: true)
        try career.open()
        defer { career.close() }
        let before = career.snapshot
        let restricted = GameContent.chapters.flatMap(\.stages).first {
            career.store.accessRestriction(for: .journey(stageID: $0.id)) != nil
        }
        let stage = try #require(restricted)
        #expect(career.play.journey.handleStagePrimaryAction(for: stage) != nil)
        #expect(career.snapshot == before)
        career.store.contentAccess = .fullGame
        #expect(career.store.reconcileAccessibleParty())
        career.store.contentAccess = .free
        #expect(career.store.reconcileAccessibleParty())
        #expect(career.snapshot == before)
    }

    @Test func `exhausted action budget cannot complete A career`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughBudget")
        defer { SaveTestSupport.removeTempDirectory(output) }
        var scenario = PlaythroughScenario()
        scenario.maxActions = 3
        let career = try PlaythroughCareer(scenario: scenario, output: output)
        do {
            _ = try await career.run(reload: false)
            Issue.record("A capped career must not complete")
        } catch PlaythroughFailure.budget {
            #expect(career.summary.termination == "budgetExhaustion")
            #expect(career.summary.outcomes.isEmpty)
        }
    }

    @Test func `fresh career matches reloaded continuation and unrelated career`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "Playthrough")
        defer { SaveTestSupport.removeTempDirectory(output) }
        let scenario = PlaythroughScenario()
        let first = try PlaythroughCareer(scenario: scenario, output: output.appendingPathComponent("alone"))
        let uninterrupted = try await first.run(reload: false)
        #expect(first.summary.outcomes.count == 2)
        #expect(first.summary.termination == "completedObjective")

        var unrelated = scenario
        unrelated.worldSeed += 1
        unrelated.combatSeed += 1
        let middle = try PlaythroughCareer(scenario: unrelated, output: output.appendingPathComponent("unrelated"))
        _ = try await middle.run(reload: true)

        let reloaded = try PlaythroughCareer(scenario: scenario, output: output.appendingPathComponent("reloaded"))
        let continuation = try await reloaded.run(reload: true)
        #expect(continuation == uninterrupted)
        #expect(reloaded.summary.outcomes == first.summary.outcomes)
        #expect(reloaded.summary.reloads == 2)
    }

    @Test func `targeted shop mystery and homestead commands persist`() async throws {
        let context = try AppTestContext()
        var before: PlayerSave
        do {
            let save = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
            let play = try context.makePlaySession(playerSave: save)
            // Targeted fixture: resources establish action coverage, never pacing.
            try save.performBatchMutation { value in
                value.roster.gold = 100
                value.homestead = .init(resources: [.wood: 20, .herbs: 10], nodeTiers: [:], lastProductionAt: .distantPast)
            }
            let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
            #expect(play.journey.handleStagePrimaryAction(for: shopStage) == nil)
            let shop = try #require(play.encounters.activeShopEncounter)
            let offer = try #require(shop.offers.first)
            #expect(play.encounters.purchaseActiveShopOffer(offerID: offer.id))
            let purchased = save.currentSave
            #expect(!play.encounters.purchaseActiveShopOffer(offerID: offer.id))
            #expect(save.currentSave == purchased)
            #expect(play.encounters.finishActiveShopEncounter())
            let recruit = try #require(GameContent.stage(id: "chapter-1-stage-2"))
            #expect(play.journey.handleStagePrimaryAction(for: recruit) == nil)
            #expect(play.encounters.finishActiveMysteryEncounter())
            let wheat = try #require(GameContent.homesteadNode(matching: .wheatField))
            let date = Date(timeIntervalSince1970: 1800000000)
            #expect(await save.buildOrUpgradeNode(wheat, targetTier: 1, at: date) == .success)
            #expect(await save.collectProduction(at: date.addingTimeInterval(PlayerHomesteadState.secondsPerDay)) == .success([.init(
                .food,
                1,
            )]))
            play.clearTransientState()
            before = save.currentSave
        }
        let reopened = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        #expect(!reopened.currentSave.hasDomainDifference(from: before))
    }
}
