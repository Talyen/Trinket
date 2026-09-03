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
    func toJourneyProgressState() -> JourneyProgressState {
        let stageModels = stages ?? []
        let pinned = Dictionary(
            stageModels.compactMap { model -> (String, String)? in
                guard let eventID = model.mysteryEventID, !eventID.isEmpty else { return nil }
                return (model.stageID, eventID)
            },
            uniquingKeysWith: { _, new in new },
        )
        return JourneyProgressState(
            activeChapterID: activeChapterID,
            activeStageID: activeStageID,
            completedStageIDs: Set(stageModels.filter(\.isCompleted).map(\.stageID)),
            claimedRewardStageIDs: Set(stageModels.filter(\.rewardsClaimed).map(\.stageID)),
            pinnedMysteryEventIDs: pinned,
        )
    }

    func update(from state: JourneyProgressState, context: ModelContext?) {
        activeChapterID = state.activeChapterID
        activeStageID = state.activeStageID
        let allStageIDs = state.completedStageIDs
            .union(state.claimedRewardStageIDs)
            .union(Set(state.pinnedMysteryEventIDs.keys))
        stages = reconcileModels(
            existing: stages ?? [],
            values: allStageIDs.sorted(),
            existingKey: \.stageID,
            valueKey: { $0 },
            make: { JourneyStageProgressModel(stageID: $0) },
            update: { model, stageID in
                model.stageID = stageID
                model.isCompleted = state.completedStageIDs.contains(stageID)
                model.rewardsClaimed = state.claimedRewardStageIDs.contains(stageID)
                model.mysteryEventID = state.pinnedMysteryEventIDs[stageID]
            },
            link: { $0.journey = self },
            context: context,
        )
    }
}
