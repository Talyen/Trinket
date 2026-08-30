import Foundation
import TrinketContent
import TrinketCore

public enum MysteryEventPinApplier {
    @discardableResult
    public static func pinLabyrinthEvent(
        nodeID: String,
        eventID: String,
        save: inout PlayerSave,
    ) -> Bool {
        guard var node = save.labyrinth.nodes[nodeID] else { return false }
        guard node.mysteryEventID == nil else { return true }
        node.mysteryEventID = eventID
        save.labyrinth.nodes[nodeID] = node
        return true
    }

    @discardableResult
    public static func pinJourneyEvent(
        stageID: String,
        eventID: String,
        save: inout PlayerSave,
    ) -> Bool {
        guard save.journey.pinnedMysteryEventIDs[stageID] == nil else { return true }
        save.journey.pinnedMysteryEventIDs[stageID] = eventID
        return true
    }
}
