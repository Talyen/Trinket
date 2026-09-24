import os
import TrinketContent
import TrinketCore

extension PlayerSaveSanitizer {
    static func sanitizeJourney(
        _ journey: JourneyProgressState,
        chapters: [Chapter]? = nil,
    ) -> JourneyProgressState {
        let activeChapters = chapters ?? GameContent.chapters
        let validChapterIDs = Set(activeChapters.map(\.id))
        let allStages = activeChapters.flatMap(\.stages)
        let validStageIDs = Set(allStages.map(\.id))

        var sanitized = journey
        let beforeCompleted = journey.completedStageIDs.count
        let beforeClaimed = journey.claimedRewardStageIDs.count
        sanitized.completedStageIDs = journey.completedStageIDs.intersection(validStageIDs)
        sanitized.claimedRewardStageIDs = journey.claimedRewardStageIDs.intersection(validStageIDs)
        if sanitized.completedStageIDs.count != beforeCompleted || sanitized.claimedRewardStageIDs.count != beforeClaimed {
            logger.info("Sanitized journey: dropped invalid stage IDs")
        }
        for stageID in sanitized.claimedRewardStageIDs {
            sanitized.completedStageIDs.insert(stageID)
        }
        let beforePinned = journey.pinnedMysteryEventIDs.count
        sanitized.pinnedMysteryEventIDs = journey.pinnedMysteryEventIDs.filter { stageID, eventID in
            guard validStageIDs.contains(stageID), !eventID.isEmpty else { return false }
            return GameContent.mysteryEvent(matching: eventID) != nil
                || GameContent.recruitEvent(matching: eventID) != nil
        }
        sanitized.shopPayloads = journey.shopPayloads.filter { stageID, _ in
            validStageIDs.contains(stageID) && !sanitized.completedStageIDs.contains(stageID)
        }
        sanitized.mysteryOfferPayloads = journey.mysteryOfferPayloads.filter { stageID, _ in
            validStageIDs.contains(stageID) && !sanitized.completedStageIDs.contains(stageID)
        }
        if sanitized.pinnedMysteryEventIDs.count != beforePinned {
            logger.info("Sanitized journey: dropped invalid pinned mystery events")
        }

        if !validChapterIDs.contains(sanitized.activeChapterID) {
            sanitized.activeChapterID = activeChapters.first?.id ?? JourneyProgressState.initial.activeChapterID
        }

        if let activeStageID = sanitized.activeStageID,
           validStageIDs.contains(activeStageID),
           !sanitized.completedStageIDs.contains(activeStageID) {
            sanitized.activeStageID = activeStageID
            if let stage = allStages.first(where: { $0.id == activeStageID }) {
                sanitized.activeChapterID = stage.chapterID
            }
        } else if let firstIncomplete = allStages.first(where: {
            $0.chapterID == sanitized.activeChapterID && !sanitized.completedStageIDs.contains($0.id)
        }) ?? allStages.first(where: { !sanitized.completedStageIDs.contains($0.id) }) {
            sanitized.activeStageID = firstIncomplete.id
            sanitized.activeChapterID = firstIncomplete.chapterID
        } else {
            sanitized.activeStageID = nil
            sanitized.activeChapterID = activeChapters.last?.id
                ?? JourneyProgressState.initial.activeChapterID
        }

        return sanitized
    }

    static func sanitizeSpires(
        _ spires: PlayerSpiresState,
        catalog: [SpireDefinition] = GameContent.spires,
    ) -> PlayerSpiresState {
        let validIDs = Set(catalog.map(\.id.rawValue))
        let floorCounts = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id.rawValue, $0.floorCount) })
        var sanitized: [String: Int] = [:]
        for (spireID, floor) in spires.highestClearedFloorBySpireID {
            guard validIDs.contains(spireID) else { continue }
            let maxFloor = floorCounts[spireID] ?? 0
            sanitized[spireID] = min(max(floor, 0), maxFloor)
        }
        return PlayerSpiresState(highestClearedFloorBySpireID: sanitized)
    }
}
