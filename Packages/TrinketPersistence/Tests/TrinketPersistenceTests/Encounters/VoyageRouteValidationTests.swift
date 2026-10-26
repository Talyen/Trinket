import Foundation
import Testing
import TrinketContent
@testable import TrinketPersistence

struct VoyageRouteValidationTests {
    @Test(arguments: ["early-boss", "ordinary-final-enemy", "boss-as-battle", "empty-run-id"]) @MainActor
    func `invalid saved Voyage routes stay opaque and cannot pay destination rewards`(damage: String) throws {
        var state = PlayerVoyageState()
        state.ensureBoard(access: .free)
        let offer = try #require(state.offers.first)
        let embarked = state.embark(offerID: offer.id, eligibleRecruitEventIDs: [], access: .free)
        #expect(embarked)
        #expect(!PlayerVoyageState.decodePayload(state.encodedPayload).isUnreadable)
        var json = try #require(JSONSerialization.jsonObject(with: state.encodedPayload) as? [String: Any])
        var run = try #require(json["activeRun"] as? [String: Any])
        var nodes = try #require(run["nodes"] as? [[String: Any]])
        switch damage {
        case "early-boss":
            nodes[1]["type"] = "boss"
            nodes[1]["enemyID"] = VoyageCatalog.bossID(chapterID: offer.chapterID)
        case "ordinary-final-enemy": nodes[nodes.count - 1]["enemyID"] = "slime"
        case "boss-as-battle": nodes[0]["enemyID"] = VoyageCatalog.bossID(chapterID: offer.chapterID)
        default:
            var destination = try #require(run["offer"] as? [String: Any])
            destination["id"] = ""
            run["offer"] = destination
        }
        run["nodes"] = nodes
        json["activeRun"] = run
        let payload = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
        var decoded = PlayerVoyageState.decodePayload(payload)
        #expect(decoded.isUnreadable)
        #expect(decoded.encodedPayload == payload)
        let firstNodeID = try #require(state.activeRun?.nodes.first?.id)
        #expect(!decoded.isPlayable(runID: offer.id, nodeID: firstNodeID))
        decoded.ensureBoard(access: .fullGame)
        #expect(decoded.encodedPayload == payload)
        var save = PlayerSave.testSeed
        save.voyage = decoded
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(save)
        #expect(reloaded.voyage.isUnreadable)
        #expect(reloaded.voyage.encodedPayload == payload)
    }
}
