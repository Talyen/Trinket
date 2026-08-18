import Foundation
import TrinketContent
import TrinketCore

/// Pins a resolved mystery event so reopen stays stable with inventory-gated picks.
public enum MysteryEventPinApplier {
    /// Pins `eventID` onto a labyrinth node when that node has no pinned event.
    @discardableResult
    public static func pinLabyrinthEvent(
        nodeID: String,
        eventID: String,
        save: inout PlayerSave
    ) -> Bool {
        guard var node = save.labyrinth.nodes[nodeID] else { return false }
        guard node.mysteryEventID == nil else { return true }
        node.mysteryEventID = eventID
        save.labyrinth.nodes[nodeID] = node
        return true
    }

    /// Pins `eventID` onto a journey stage when that stage has no pinned event.
    @discardableResult
    public static func pinJourneyEvent(
        stageID: String,
        eventID: String,
        save: inout PlayerSave
    ) -> Bool {
        guard save.journey.pinnedMysteryEventIDs[stageID] == nil else { return true }
        save.journey.pinnedMysteryEventIDs[stageID] = eventID
        return true
    }
}
