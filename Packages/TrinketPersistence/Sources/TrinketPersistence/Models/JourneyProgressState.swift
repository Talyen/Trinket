import Foundation

public struct JourneyProgressState: Codable, Equatable, Sendable {
    public var activeChapterID: String
    public var activeStageID: String?
    public var completedStageIDs: Set<String>
    public var claimedRewardStageIDs: Set<String>
    public var lastCompletedStageID: String?

    public static let initial = JourneyProgressState(
        activeChapterID: "chapter-1",
        activeStageID: "chapter-1-stage-1",
        completedStageIDs: [],
        claimedRewardStageIDs: [],
        lastCompletedStageID: nil
    )

    public init(
        activeChapterID: String,
        activeStageID: String?,
        completedStageIDs: Set<String>,
        claimedRewardStageIDs: Set<String>,
        lastCompletedStageID: String?
    ) {
        self.activeChapterID = activeChapterID
        self.activeStageID = activeStageID
        self.completedStageIDs = completedStageIDs
        self.claimedRewardStageIDs = claimedRewardStageIDs
        self.lastCompletedStageID = lastCompletedStageID
    }
}

public extension JourneyProgressState {
    var current: JourneyProgressState {
        get { self }
        set { self = newValue }
    }
}
