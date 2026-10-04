import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import TrinketAppState

@MainActor
struct MysteryEncounterSessionTests {
    @Test func `returning to choices releases reveal and reward payloads`() throws {
        let session = try makeSession()
        let result = MysteryEffectResult(grantedGold: 20)
        session.applyOutcome(.reveal(unlockedCombatantID: "bear"))
        #expect(session.showsReveal)
        #expect(session.unlockedCombatantID == "bear")

        session.applyOutcome(.reward(result))
        #expect(session.showsReward)
        #expect(session.applyResult == result)
        #expect(session.claimRewardCollectionSound())
        #expect(!session.claimRewardCollectionSound())
        #expect(session.unlockedCombatantID == nil)
        #expect(!session.showsReveal)

        session.markChoiceStarted()
        session.applyOutcome(.refreshedOffers([]))
        #expect(session.canResolveChoice)
        #expect(!session.showsReward)
        #expect(session.applyResult == nil)
        #expect(session.persistFailureMessage != nil)
    }

    @Test func `corruption reveal releases selection and returning to reading releases result`() throws {
        let session = try makeSession()
        let item = try makeItem()
        session.applyOutcome(.selectCorruptItem, inventory: PlayerInventoryState(items: [item]))
        #expect(session.showsCorruptItemChoice)
        #expect(session.corruptibleItems == [item])
        let result = ItemCorruptionDetail(originalItem: item, item: item, effects: [.upgradedRarity])
        session.applyOutcome(.corruptionReveal(result))
        #expect(session.showsCorruptionReveal)
        #expect(session.corruptionResult == result)
        #expect(session.corruptibleItems.isEmpty)

        session.returnToReading()
        #expect(session.canResolveChoice)
        #expect(!session.showsCorruptionReveal)
        #expect(session.corruptionResult == nil)
    }

    @Test func `failure and retry preserve presentation but successful outcome clears attempt status`() throws {
        let session = try makeSession()
        let item = try makeItem()
        session.applyOutcome(.selectCorruptItem, inventory: PlayerInventoryState(items: [item]))
        let items = session.corruptibleItems
        session.markChoiceStarted()
        #expect(session.isResolvingChoice)
        session.clearPersistFailure()
        #expect(session.isResolvingChoice)

        session.markPersistFailed("Unavailable")
        #expect(!session.isResolvingChoice)
        #expect(session.persistFailureMessage == "Unavailable")
        #expect(session.showsCorruptItemChoice)
        #expect(session.corruptibleItems == items)
        #expect(!session.canResolveChoice)

        session.markChoiceStarted()
        #expect(session.persistFailureMessage == nil)
        session.applyOutcome(.reveal(unlockedCombatantID: "bear"))
        #expect(!session.isResolvingChoice)
        #expect(session.persistFailureMessage == nil)
        #expect(session.corruptibleItems.isEmpty)
        #expect(session.showsReveal)
    }

    private func makeItem() throws -> InventoryItem {
        let base = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let affix = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        return InventoryItem(
            id: "session-corruption", baseType: base, rarity: .basic,
            displayName: base.name, affixes: [affix.resolved(for: .basic)],
        )
    }

    private func makeSession() throws -> MysteryEncounterSession {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        let origin = PlayEncounterOrigin.journey(stage: stage)
        return MysteryEncounterSession(
            origin: origin, encounter: origin.identity(in: .testSeed), event: event, combatant: nil,
        )
    }
}
