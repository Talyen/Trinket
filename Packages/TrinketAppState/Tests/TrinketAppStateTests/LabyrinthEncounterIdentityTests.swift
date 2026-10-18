import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct LabyrinthEncounterIdentityTests {
    @Test(arguments: [false, true])
    func `retained Labyrinth shops use their map seed and preserve session ownership`(replaceSave: Bool) throws {
        let context = try AppTestContext()
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .shop, in: state))
        try state.playerSave.performFixtureMutation { save in
            save.worldSeed ^= 1
        }
        #expect(state.playerSave.labyrinth.worldSeed != state.playerSave.worldSeed)
        #expect(state.encounters.beginShopOrAutoComplete(origin: .labyrinth(nodeID: nodeID)) == nil)
        let retired = try #require(state.encounters.activeShopEncounter)
        let offer = try #require(retired.offers.first)
        let current = ShopEncounterSession(origin: retired.origin, encounter: retired.encounter, offers: retired.offers)
        state.encounters.activeShopEncounter = current
        try state.playerSave.performFixtureMutation { save in
            save.roster.gold = offer.price * 3
            if replaceSave {
                save.sessionGeneration &+= 1
            }
        }
        let before = state.playerSave.currentSave

        #expect(state.encounters.purchaseShopOffer(session: retired, offerID: offer.id) == .rejected)
        #expect(!state.encounters.finishShopEncounter(session: retired))
        #expect(state.playerSave.currentSave == before)
        if replaceSave {
            #expect(state.encounters.purchaseShopOffer(session: current, offerID: offer.id) == .rejected)
            #expect(!state.encounters.finishShopEncounter(session: current))
            #expect(state.playerSave.currentSave == before)
            #expect(state.encounters.activeShopEncounter === current)
        } else {
            #expect(state.encounters.purchaseShopOffer(session: current, offerID: offer.id) == .committed)
            #expect(state.playerSave.roster.gold == before.roster.gold - offer.price)
            #expect(current.lastPurchasedOfferID == offer.id)
            #expect(state.encounters.finishShopEncounter(session: current))
            #expect(state.playerSave.labyrinth.nodes[nodeID]?.isCleared == true)
            #expect(state.encounters.activeShopEncounter == nil)
        }
    }
}
