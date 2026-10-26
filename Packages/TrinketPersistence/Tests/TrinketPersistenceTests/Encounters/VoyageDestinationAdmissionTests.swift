import Foundation
import Testing
import TrinketContent
@testable import TrinketPersistence

struct VoyageDestinationAdmissionTests {
    @Test(arguments: [false, true]) @MainActor
    func `unknown Voyage destinations preserve opaque board and route progress through reload`(activeRoute: Bool) throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        let offer = try #require(state.offers.first)
        let embarked = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        let firstNodeID = try #require(state.activeRun?.nodes.first?.id)
        if !activeRoute {
            state.activeRun = nil
        }
        #expect(!PlayerVoyageState.decodePayload(state.encodedPayload).isUnreadable)

        var json = try #require(JSONSerialization.jsonObject(with: state.encodedPayload) as? [String: Any])
        if activeRoute {
            var run = try #require(json["activeRun"] as? [String: Any])
            var destination = try #require(run["offer"] as? [String: Any])
            destination["chapterID"] = "chapter-999"
            run["offer"] = destination
            json["activeRun"] = run
        } else {
            var offers = try #require(json["offers"] as? [[String: Any]])
            offers[0]["chapterID"] = "chapter-999"
            json["offers"] = offers
        }
        let payload = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        var decoded = PlayerVoyageState.decodePayload(payload)
        #expect(decoded.isUnreadable)
        #expect(decoded.encodedPayload == payload)
        #expect(!decoded.isPlayable(runID: offer.id, nodeID: firstNodeID))
        decoded.ensureBoard(access: .fullGame)
        decoded.refresh(access: .fullGame)
        #expect(decoded.encodedPayload == payload)
        let reembarked = decoded.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .fullGame)
        #expect(!reembarked)

        var save = PlayerSave.testSeed
        save.voyage = decoded
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(save)
        #expect(reloaded.voyage.isUnreadable)
        #expect(reloaded.voyage.encodedPayload == payload)
    }
}
