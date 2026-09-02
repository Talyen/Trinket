import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
struct StarterSelectionTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `draft and chosen party survive reload`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )

        #expect(firstStore.starterSelection == .fresh)
        #expect(firstStore.confirmStarterHero("warlock"))

        let resumedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(
            resumedStore.starterSelection
                == StarterSelectionState(phase: .chooseCompanion, heroID: "warlock"),
        )
        #expect(resumedStore.completeStarterSelection(companionID: "pixie"))

        let completedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(completedStore.starterSelection == .complete)
        #expect(completedStore.roster.activeHeroID == "warlock")
        #expect(completedStore.roster.activeCompanionID == "pixie")
        #expect(completedStore.roster.unlockedHeroIDs == ["warlock"])
        #expect(completedStore.roster.unlockedCompanionIDs == ["pixie"])
        #expect(completedStore.roster.progressions == [
            "warlock": .initial,
            "pixie": .initial,
        ])
    }

    @Test func `pre starter selection save is grandfathered past onboarding`() {
        let root = PlayerSaveRoot(save: .fresh)
        root.schemaVersion = 15
        root.starterSelectionPhaseRawValue = StarterSelectionPhase.chooseHero.rawValue

        #expect(root.toPlayerSave().starterSelection == .complete)
    }

    @Test func `invalid drafts normalize and completed selection cannot reopen`() throws {
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
