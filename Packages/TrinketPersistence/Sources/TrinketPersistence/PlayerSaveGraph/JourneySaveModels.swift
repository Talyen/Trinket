import Foundation
import SwiftData
import TrinketCore

@Model
public final class JourneyProgressModel {
    public var activeChapterID: String = JourneyProgressState.initial.activeChapterID
    public var activeStageID: String?
    public var lastCompletedStageID: String?
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
    public var journey: JourneyProgressModel?

    public init(stageID: String = "", isCompleted: Bool = false, rewardsClaimed: Bool = false) {
        self.stageID = stageID
        self.isCompleted = isCompleted
        self.rewardsClaimed = rewardsClaimed
    }
}
