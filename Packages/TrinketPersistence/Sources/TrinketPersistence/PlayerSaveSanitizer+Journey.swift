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
        sanitized.completedStageIDs.formUnion(sanitized.claimedRewardStageIDs)
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

        let incomplete = allStages.filter { !sanitized.completedStageIDs.contains($0.id) }
        let activeStage = incomplete.first { $0.id == sanitized.activeStageID }
            ?? incomplete.first { $0.chapterID == sanitized.activeChapterID }
            ?? incomplete.first
        sanitized.activeStageID = activeStage?.id
        sanitized.activeChapterID = activeStage?.chapterID ?? activeChapters.last?.id
            ?? JourneyProgressState.initial.activeChapterID

        return sanitized
    }

    static func sanitizeSpires(
        _ spires: PlayerSpiresState,
        catalog: [SpireDefinition] = GameContent.spires,
    ) -> PlayerSpiresState {
        let floorCounts = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id.rawValue, $0.floorCount) })
        var sanitized: [String: Int] = [:]
        for (spireID, floor) in spires.highestClearedFloorBySpireID {
            guard let maxFloor = floorCounts[spireID] else { continue }
            sanitized[spireID] = min(max(floor, 0), maxFloor)
        }
        return PlayerSpiresState(highestClearedFloorBySpireID: sanitized)
    }
}
