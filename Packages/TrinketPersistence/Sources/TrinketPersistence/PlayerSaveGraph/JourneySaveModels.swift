import Foundation
import SwiftData
import TrinketCore

@Model
final class JourneyProgressModel {
    var activeChapterID: String = JourneyProgressState.initial.activeChapterID
    var activeStageID: String?
    var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \JourneyStageProgressModel.journey)
    var stages: [JourneyStageProgressModel]?

    init() {}
}

@Model
final class JourneyStageProgressModel {
    var stageID: String = ""
    var isCompleted: Bool = false
    var rewardsClaimed: Bool = false
    var mysteryEventID: String?
    var mysteryOffersPayload: Data?
    var shopPayload: Data?
    var journey: JourneyProgressModel?

    init(
        stageID: String = "",
        isCompleted: Bool = false,
        rewardsClaimed: Bool = false,
        mysteryEventID: String? = nil,
    ) {
        self.stageID = stageID
        self.isCompleted = isCompleted
        self.rewardsClaimed = rewardsClaimed
        self.mysteryEventID = mysteryEventID
    }
}

extension JourneyProgressModel {
    func toPlayerJourneyState() -> JourneyProgressState {
        var state = JourneyProgressState(
            activeChapterID: activeChapterID,
            activeStageID: activeStageID,
            completedStageIDs: [],
            claimedRewardStageIDs: [],
        )
        for model in stages ?? [] {
            if model.isCompleted {
                state.completedStageIDs.insert(model.stageID)
            }
            if model.rewardsClaimed {
                state.claimedRewardStageIDs.insert(model.stageID)
            }
            if let eventID = model.mysteryEventID, !eventID.isEmpty {
                state.pinnedMysteryEventIDs[model.stageID] = eventID
            }
            if let payload = model.mysteryOffersPayload {
                state.mysteryOfferPayloads[model.stageID] = payload
            }
            if let payload = model.shopPayload {
                state.shopPayloads[model.stageID] = payload
            }
        }
        return state
    }

    func update(from state: JourneyProgressState, context: ModelContext?) {
        activeChapterID = state.activeChapterID
        activeStageID = state.activeStageID
        let allStageIDs = state.completedStageIDs
            .union(state.claimedRewardStageIDs)
            .union(Set(state.pinnedMysteryEventIDs.keys))
            .union(Set(state.mysteryOfferPayloads.keys))
            .union(Set(state.shopPayloads.keys))
        stages = reconcileModels(
            existing: stages ?? [],
            values: allStageIDs.sorted(),
            existingKey: \.stageID,
            valueKey: { $0 },
            make: { JourneyStageProgressModel() },
            update: { model, stageID in
                model.stageID = stageID
                model.isCompleted = state.completedStageIDs.contains(stageID)
                model.rewardsClaimed = state.claimedRewardStageIDs.contains(stageID)
                model.mysteryEventID = state.pinnedMysteryEventIDs[stageID]
                model.mysteryOffersPayload = state.mysteryOfferPayloads[stageID]
                model.shopPayload = state.shopPayloads[stageID]
            },
            link: { $0.journey = self },
            context: context,
        )
    }
}
