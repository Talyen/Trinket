import Foundation
import SwiftData
import TrinketCore

@Model
public final class JourneyProgressModel {
    public var activeChapterID: String = JourneyProgressState.initial.activeChapterID
    public var activeStageID: String?
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \JourneyStageProgressModel.journey)
    public var stages: [JourneyStageProgressModel]?

    public init() {}
}

@Model
public final class JourneyStageProgressModel {
    public var stageID: String = ""
    public var isCompleted: Bool = false
    public var rewardsClaimed: Bool = false
    public var mysteryEventID: String?
    public var mysteryOffersPayload: Data?
    public var shopPayload: Data?
    public var journey: JourneyProgressModel?

    public init(
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
