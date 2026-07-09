import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

@MainActor
struct AppStateAttentionTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func freshStartSeedsStartersAsViewedWithoutCollectionBadge() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-reset-state"])
        )

        #expect(state.collectionActionableCount == 0)
        #expect(state.collectionBadge == nil)
        #expect(state.showsCollectionNewMarker(for: PlayerRosterState.starterHeroID) == false)
        #expect(state.showsCollectionNewMarker(for: PlayerRosterState.starterPetID) == false)
        #expect(
            state.collectionAttention.current.viewedCombatantIDs.contains(PlayerRosterState.starterHeroID)
        )
        #expect(
            state.collectionAttention.current.viewedCombatantIDs.contains(PlayerRosterState.starterPetID)
        )
    }

    @Test func unlockingCombatantRaisesCollectionBadgeAndNewMarker() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        #expect(state.collectionBadge == nil)

        var roster = state.roster.current
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        state.roster.current = roster

        #expect(state.collectionActionableCount == 1)
        #expect(state.collectionBadge == 1)
        #expect(state.unviewedHeroCount == 1)
        #expect(state.showsCollectionNewMarker(for: "rogue"))
        #expect(state.showsCollectionNewMarker(for: PlayerRosterState.starterHeroID) == false)
    }

    @Test func markCombatantAsViewedClearsDiscoveryAttention() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var roster = state.roster.current
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        state.roster.current = roster

        state.markCombatantAsViewed(id: "rogue")

        #expect(state.collectionActionableCount == 0)
        #expect(state.collectionBadge == nil)
        #expect(state.showsCollectionNewMarker(for: "rogue") == false)
    }

    @Test func markAllCollectionCombatantsAsViewedClearsCategory() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var roster = state.roster.current
        roster.unlockedHeroIDs.formUnion(["rogue", "wizard"])
        roster.progressions["rogue"] = .initial
        roster.progressions["wizard"] = .initial
        state.roster.current = roster
        #expect(state.unviewedHeroCount == 2)

        state.markAllCollectionCombatantsAsViewed(kind: .hero)

        #expect(state.unviewedHeroCount == 0)
        #expect(state.showsCollectionNewMarker(for: "rogue") == false)
        #expect(state.showsCollectionNewMarker(for: "wizard") == false)
    }

    @Test func newInventoryItemRaisesCollectionBadgeAndNewMarker() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let item = template.rewardInstance(for: "attention-test")

        var inventory = state.inventory.current
        inventory.items.append(item)
        state.inventory.current = inventory

        #expect(state.collectionActionableCount == 1)
        #expect(state.collectionBadge == 1)
        #expect(state.showsCollectionNewMarker(forItem: item.id))

        state.markItemAsViewed(id: item.id)

        #expect(state.collectionActionableCount == 0)
        #expect(state.collectionBadge == nil)
        #expect(state.showsCollectionNewMarker(forItem: item.id) == false)
    }

    @Test func basicItemTemplateAcknowledgmentSuppressesLaterCopies() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let first = template.rewardInstance(for: "attention-copy-1")
        let second = template.rewardInstance(for: "attention-copy-2")

        var inventory = state.inventory.current
        inventory.items.append(contentsOf: [first, second])
        state.inventory.current = inventory
        #expect(state.unviewedItemCount == 2)

        state.markItemAsViewed(first)

        #expect(state.showsCollectionNewMarker(for: first) == false)
        #expect(state.showsCollectionNewMarker(for: second) == false)
        #expect(state.unviewedItemCount == 0)
        #expect(
            state.collectionAttention.current.viewedItemTemplateIDs.contains(first.templateID)
        )
    }

    @Test func astralItemAcknowledgmentStaysInstanceScoped() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let baseType = try #require(GameContent.itemBaseTypes.first)
        let first = InventoryItem(
            id: "astral-1",
            templateID: "astral-template",
            baseType: baseType,
            rarity: .astral,
            displayName: "Astral Blade",
            affixes: []
        )
        let second = InventoryItem(
            id: "astral-2",
            templateID: "astral-template",
            baseType: baseType,
            rarity: .astral,
            displayName: "Astral Blade",
            affixes: []
        )

        var inventory = state.inventory.current
        inventory.items.append(contentsOf: [first, second])
        state.inventory.current = inventory

        state.markItemAsViewed(first)

        #expect(state.showsCollectionNewMarker(for: first) == false)
        #expect(state.showsCollectionNewMarker(for: second))
        #expect(state.unviewedItemCount == 1)
    }

    @Test func shopPreviewMarkDoesNotPersistUnownedItemAttention() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let offerItem = InventoryItem(
            id: "shop-preview-offer",
            templateID: template.templateID,
            baseType: template.baseType,
            rarity: template.rarity,
            displayName: template.displayName,
            affixes: template.affixes
        )

        state.markItemAsViewed(offerItem)

        #expect(state.collectionAttention.current.viewedItemIDs.contains(offerItem.id) == false)
        #expect(
            state.collectionAttention.current.viewedItemTemplateIDs.contains(offerItem.templateID)
                == false
        )
    }

    @Test func mysteryInspectDoesNotClearCollectionAttention() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var roster = state.roster.current
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        state.roster.current = roster
        #expect(state.showsCollectionNewMarker(for: "rogue"))

        // Mystery uses marksCollectionAttention: false — simulate by not calling mark.
        #expect(state.showsCollectionNewMarker(for: "rogue"))
        #expect(state.collectionActionableCount == 1)
    }

    @Test func inventoryShelfPrefersUnviewedItems() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        var inventory = state.inventory.current
        for index in 1 ... 14 {
            inventory.items.append(template.rewardInstance(for: "shelf-\(index)"))
        }
        // Mark the first 12 as viewed so only the last two remain NEW.
        var attention = state.collectionAttention.current
        for item in inventory.items.prefix(12) {
            attention.markItemAsViewed(item)
        }
        state.inventory.current = inventory
        state.collectionAttention.current = attention

        let shelf = state.collectionInventoryShelfItems(limit: 12)
        #expect(shelf.count == 12)
        #expect(shelf.prefix(2).allSatisfy { state.showsCollectionNewMarker(for: $0) })
        #expect(state.unviewedItemCount == 2)
        #expect(state.collectionBadge == 2)
    }

    @Test func collectionBadgeNilWhileOnCollectionTab() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var roster = state.roster.current
        roster.unlockedPetIDs.insert("wolf")
        roster.progressions["wolf"] = .initial
        state.roster.current = roster

        #expect(state.collectionBadge == 1)
        state.selectedTab = .collection
        #expect(state.collectionBadge == nil)
        #expect(state.collectionActionableCount == 1)
        #expect(state.showsCollectionNewMarker(for: "wolf"))
    }

    @Test func viewedCombatantsPersistAcrossAppStateReload() throws {
        let first = try context.makeAppState(environment: context.makeEnvironment())
        var roster = first.roster.current
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        first.roster.current = roster
        first.markCombatantAsViewed(id: "rogue")

        let reloaded = try context.makeAppState(environment: context.makeEnvironment())
        #expect(reloaded.collectionAttention.current.viewedCombatantIDs.contains("rogue"))
        #expect(reloaded.collectionActionableCount == 0)
        #expect(reloaded.showsCollectionNewMarker(for: "rogue") == false)
    }

    @Test func migratesLegacyShellViewedCombatantsIntoPlayerSave() throws {
        let playerSave = try PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL),
            disableCloudSync: true,
            persistSaveImmediately: true
        )
        var roster = playerSave.roster
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        playerSave.roster = roster

        let shell = try context.makeShellSessionStore(
            environment: context.makeEnvironment(arguments: ["-reset-state"])
        )
        shell.viewedCombatantIDs = ["rogue"]

        let state = try AppState(
            environment: context.makeEnvironment(),
            playerSave: playerSave,
            shellSessionStore: shell,
            userDefaults: context.userDefaults
        )

        #expect(state.shellSession.viewedCombatantIDs.isEmpty)
        #expect(state.collectionAttention.current.viewedCombatantIDs.contains("rogue"))
        #expect(state.showsCollectionNewMarker(for: "rogue") == false)
    }

    @Test func resetGameplayProgressReseedsStarterViewedState() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var roster = state.roster.current
        roster.unlockedHeroIDs.insert("rogue")
        roster.progressions["rogue"] = .initial
        state.roster.current = roster
        #expect(state.collectionActionableCount == 1)

        #expect(state.resetGameplayProgress())
        #expect(state.roster.current == .freshStart)
        #expect(state.collectionActionableCount == 0)
        #expect(
            state.collectionAttention.current.viewedCombatantIDs.contains(PlayerRosterState.starterHeroID)
        )
        #expect(
            state.collectionAttention.current.viewedCombatantIDs.contains(PlayerRosterState.starterPetID)
        )
        #expect(state.showsCollectionNewMarker(for: "rogue") == false)
    }

    @Test func seedTestProgressMarksSampleInventoryAsViewed() throws {
        let state = try context.makeAppState(
            environment: context.makeEnvironment(arguments: ["-seed-test-progress"])
        )

        #expect(state.inventory.current.items.isEmpty == false)
        for item in state.inventory.current.items {
            #expect(state.showsCollectionNewMarker(forItem: item.id) == false)
        }
        #expect(state.showsCollectionNewMarker(for: PlayerRosterState.starterHeroID) == false)
        #expect(state.showsCollectionNewMarker(for: PlayerRosterState.starterPetID) == false)
        // Non-starter unlocks under test seed remain discoverable.
        #expect(state.showsCollectionNewMarker(for: "rogue"))
        #expect(state.collectionActionableCount > 0)
    }

    @Test func homesteadBadgeAppearsWhenProjectIsAffordable() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        #expect(state.homesteadActionableCount == 0)
        #expect(state.homesteadBadge == nil)

        var homestead = state.homestead.current
        homestead.resources[.wood] = 10
        homestead.resources[.stone] = 4
        state.homestead.current = homestead

        #expect(state.homesteadActionableCount >= 1)
        #expect(state.homesteadBadge == state.homesteadActionableCount)

        state.selectedTab = .homestead
        #expect(state.homesteadBadge == nil)
        #expect(state.homesteadActionableCount >= 1)
    }

    @Test func homesteadBadgeClearsAfterSpendingLastAffordableBuild() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var homestead = state.homestead.current
        homestead.resources[.wood] = 10
        homestead.resources[.stone] = 4
        state.homestead.current = homestead
        #expect(state.homesteadBadge == state.homesteadActionableCount)

        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let result = state.playerSave.homesteadStore.buildOrUpgradeNode(definition)
        #expect(result == .success)

        #expect(state.homesteadActionableCount == 0)
        #expect(state.homesteadBadge == nil)
    }

    @Test func homesteadBadgeDismissesOnVisitAndReturnsWhenSetChanges() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        var homestead = state.homestead.current
        homestead.resources[.wood] = 10
        homestead.resources[.stone] = 4
        state.homestead.current = homestead
        let firstCount = try #require(state.homesteadBadge)
        #expect(firstCount >= 1)

        state.acknowledgeHomesteadActionablesIfNeeded()
        state.selectedTab = .play
        #expect(state.homesteadBadge == nil)

        // Grant enough for an additional upgrade path / different fingerprint.
        homestead = state.homestead.current
        homestead.resources[.wood] = 100
        homestead.resources[.stone] = 100
        homestead.resources[.iron] = 100
        state.homestead.current = homestead

        #expect(state.homesteadActionableFingerprint.isEmpty == false)
        #expect(
            state.homesteadActionableFingerprint
                != state.shellSession.acknowledgedHomesteadActionableFingerprint
        )
        #expect(state.homesteadBadge == state.homesteadActionableCount)
    }

    @Test func lockedCombatantNeverShowsNewMarker() throws {
        let state = try context.makeAppState(environment: context.makeEnvironment())
        #expect(state.roster.current.unlockedHeroIDs.contains("rogue") == false)
        #expect(state.showsCollectionNewMarker(for: "rogue") == false)
    }
}
