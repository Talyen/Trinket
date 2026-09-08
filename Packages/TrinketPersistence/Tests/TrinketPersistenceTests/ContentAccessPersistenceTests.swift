import Testing
import TrinketContent
import TrinketPersistence

@Suite("Content access preservation")
struct ContentAccessPersistenceTests {
    @Test @MainActor
    func `losing access preserves premium progress across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        store.contentAccess = .fullGame
        #expect(store.confirmStarterHero("warlock"))
        #expect(store.completeStarterSelection(companionID: "phoenix"))
        let warlock = try #require(GameContent.combatant(matching: "warlock"))
        #expect(store.mutateRoster(logging: "Test premium progress") { roster in
            roster.gold = 41
            _ = roster.grantExperience(5, to: warlock)
        })
        let progress = store.roster.progressions
        store.contentAccess = .free
        #expect(store.reconcileAccessibleParty())
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.unlockedHeroIDs.contains("warlock"))
        #expect(reloaded.roster.unlockedCompanionIDs.contains("phoenix"))
        #expect(reloaded.roster.activeHeroID == "knight")
        #expect(reloaded.roster.activeCompanionID == "wolf")
        #expect(reloaded.roster.progressions["warlock"] == progress["warlock"])
        #expect(reloaded.roster.gold == 41)
        #expect(reloaded.contentAccess == .free)
        reloaded.contentAccess = .fullGame
        try reloaded.resetGameplayProgress()
        #expect(reloaded.contentAccess == .fullGame)
    }

    @Test @MainActor
    func `premium starter cannot be confirmed without access`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(!store.confirmStarterHero("warlock"))
        #expect(store.confirmStarterHero("rogue"))
        #expect(!store.completeStarterSelection(companionID: "phoenix"))
        #expect(store.completeStarterSelection(companionID: "library_owl"))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.activeHeroID == "rogue")
        #expect(reloaded.roster.activeCompanionID == "library_owl")
    }
}
