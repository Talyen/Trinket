import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct StarterSelectionTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test(arguments: ["warlock", "alchemist", "druid", "wildcard"])
    @MainActor func `starter party survives reload`(heroID: String) throws {
        let firstStore = try context.makeSaveStore()

        #expect(firstStore.starterSelection == .fresh)
        #expect(firstStore.confirmStarterHero(heroID))

        let resumedStore = try context.makeReloadedStore()
        #expect(
            resumedStore.starterSelection
                == StarterSelectionState(phase: .chooseCompanion, heroID: heroID),
        )
        #expect(resumedStore.completeStarterSelection(companionID: "pixie"))

        let completedStore = try context.makeReloadedStore()
        #expect(completedStore.starterSelection == .complete)
        #expect(completedStore.roster.activeHeroID == heroID)
        #expect(completedStore.roster.activeCompanionID == "pixie")
        #expect(completedStore.roster.unlockedHeroIDs == [heroID])
        #expect(completedStore.roster.unlockedCompanionIDs == ["pixie"])
        #expect(completedStore.roster.progressions == [
            heroID: .initial,
            "pixie": .initial,
        ])
    }

    @Test func `pre starter selection save is grandfathered past onboarding`() {
        let root = PlayerSaveRoot(save: .fresh)
        root.schemaVersion = 15
        root.starterSelectionPhaseRawValue = StarterSelectionPhase.chooseHero.rawValue

        #expect(root.toPlayerSave().starterSelection == .complete)
    }

    @Test @MainActor func `invalid drafts normalize and completed selection cannot reopen`() throws {
        #expect(StarterSelectionState(phase: .chooseCompanion) == .fresh)
        #expect(StarterSelectionState(phase: .chooseCompanion, heroID: "enemy") == .fresh)
        #expect(StarterSelectionState(phase: .chooseHero, heroID: "knight") == .fresh)
        #expect(StarterSelectionState(phase: .complete, heroID: "knight") == .complete)

        let store = try context.makeSaveStore(inMemoryOnly: true)
        #expect(!store.confirmStarterHero("not-a-hero"))
        #expect(!store.completeStarterSelection(companionID: "wolf"))
        #expect(store.confirmStarterHero("knight"))
        #expect(!store.completeStarterSelection(companionID: "not-a-companion"))
        #expect(store.completeStarterSelection(companionID: "wolf"))
        #expect(!store.confirmStarterHero("rogue"))
        #expect(store.starterSelection == .complete)
    }
}
