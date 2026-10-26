import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayModeCommandAdmissionTests {
    @Test @MainActor func `unavailable play mode commands reject before save admission`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.prepareVoyage().value)
        let before = store.currentSave
        let revision = store.commitRevision
        #if DEBUG
        store.forcesNextSaveFailure = true
        #endif

        for result in [
            store.embarkVoyage(offerID: "missing-offer"),
            store.abandonVoyage(runID: "missing-run"),
            store.refreshContracts(),
        ] {
            #expect(!result.value)
            #expect(result.failure == nil)
        }

        #expect(store.currentSave == before)
        #expect(store.commitRevision == revision)
        #if DEBUG
        #expect(store.forcesNextSaveFailure)
        store.forcesNextSaveFailure = false
        #endif
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage == before.voyage)
        #expect(reloaded.contracts == before.contracts)
    }

    @Test @MainActor func `accepted play mode commands survive reload and stale repeats reject`() throws {
        let context = try PersistenceTestContext()
        var save = SaveTestSupport.makeSave()
        save.voyage.ensureBoard(access: .free)
        save.contracts.ensureBoard()
        save.contracts.earnRefresh()
        let store = try context.seedAndReload(save)
        let offer = try #require(store.voyage.offers.first)

        #expect(store.embarkVoyage(offerID: offer.id) == SaveActionAttempt(true))
        #expect(try context.makeReloadedStore().voyage == store.voyage)
        #expect(!store.embarkVoyage(offerID: offer.id).value)
        #expect(!store.abandonVoyage(runID: "stale-run").value)
        #expect(store.abandonVoyage(runID: offer.id) == SaveActionAttempt(true))
        let abandoned = try context.makeReloadedStore()
        #expect(abandoned.voyage.activeRun == nil)
        #expect(abandoned.voyage.abandonedRunIDs?.contains(offer.id) == true)
        #expect(!store.embarkVoyage(offerID: offer.id).value)
        #expect(!store.abandonVoyage(runID: offer.id).value)

        #expect(store.refreshContracts() == SaveActionAttempt(true))
        let refreshed = try context.makeReloadedStore()
        #expect(refreshed.contracts == store.contracts)
        #expect(!refreshed.contracts.refreshAvailable)
        #expect(refreshed.contracts.offers != save.contracts.offers)
        #expect(store.refreshContracts() == SaveActionAttempt(false))
    }

    #if DEBUG
    @Test(arguments: ["embark", "abandon", "refresh"]) @MainActor
    func `play mode write failures retain retryable causes and do not publish`(command: String) throws {
        let context = try PersistenceTestContext()
        var save = SaveTestSupport.makeSave()
        save.voyage.ensureBoard(access: .free)
        save.contracts.ensureBoard()
        save.contracts.earnRefresh()
        let offer = try #require(save.voyage.offers.first)
        if command == "abandon" {
            let embarked = save.voyage.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
            #expect(embarked)
        }
        let store = try context.seedAndReload(save)
        let before = store.currentSave
        let mutate: () -> SaveActionAttempt<Bool> = {
            switch command {
            case "embark": store.embarkVoyage(offerID: offer.id)
            case "abandon": store.abandonVoyage(runID: offer.id)
            default: store.refreshContracts()
            }
        }
        store.forcesNextSaveFailure = true

        let failed = mutate()

        #expect(!failed.value)
        #expect(failed.failure == .writeFailed)
        #expect(failed.failure?.isRetryable == true)
        #expect(store.currentSave == before)
        #expect(mutate() == SaveActionAttempt(true))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.voyage == store.voyage)
        #expect(reloaded.contracts == store.contracts)
    }
    #endif
}
