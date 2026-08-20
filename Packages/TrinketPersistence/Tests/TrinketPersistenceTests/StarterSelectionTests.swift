import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
struct StarterSelectionTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func draftAndChosenPartySurviveReload() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
        )

        #expect(firstStore.starterSelection == .fresh)
        #expect(firstStore.confirmStarterHero("rogue"))

        let resumedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(
            resumedStore.starterSelection
                == StarterSelectionState(phase: .chooseCompanion, heroID: "rogue")
        )
        #expect(resumedStore.completeStarterSelection(companionID: "panther"))

        let completedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(completedStore.starterSelection == .complete)
        #expect(completedStore.roster.activeHeroID == "rogue")
        #expect(completedStore.roster.activeCompanionID == "panther")
        #expect(completedStore.roster.unlockedHeroIDs == ["rogue"])
        #expect(completedStore.roster.unlockedCompanionIDs == ["panther"])
        #expect(completedStore.roster.progressions == [
            "rogue": .initial,
            "panther": .initial,
        ])
    }

    @Test func preStarterSelectionSaveIsGrandfatheredPastOnboarding() {
        let root = PlayerSaveRoot(save: .fresh)
        root.schemaVersion = 15
        root.starterSelectionPhaseRawValue = StarterSelectionPhase.chooseHero.rawValue

        #expect(root.toPlayerSave().starterSelection == .complete)
    }

    @Test func invalidDraftsNormalizeAndCompletedSelectionCannotReopen() throws {
        #expect(StarterSelectionState(phase: .chooseCompanion) == .fresh)
        #expect(StarterSelectionState(phase: .chooseCompanion, heroID: "enemy") == .fresh)
        #expect(StarterSelectionState(phase: .chooseHero, heroID: "knight") == .fresh)
        #expect(StarterSelectionState(phase: .complete, heroID: "knight") == .complete)

        let store = try context.makeSaveStore()
        #expect(store.confirmStarterHero("knight"))
        #expect(store.completeStarterSelection(companionID: "wolf"))
        #expect(!store.confirmStarterHero("rogue"))
        #expect(store.starterSelection == .complete)
    }
}
