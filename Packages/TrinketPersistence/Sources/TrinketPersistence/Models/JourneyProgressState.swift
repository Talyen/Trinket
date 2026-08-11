import Foundation

public struct JourneyProgressState: Equatable, Sendable {
    public var activeChapterID: String
    public var activeStageID: String?
    public var completedStageIDs: Set<String>
    public var claimedRewardStageIDs: Set<String>
    /// Seeded/opened journey mystery event per stage (Labyrinth-style pin).
    public var pinnedMysteryEventIDs: [String: String]

    public static let initial = Self(
        activeChapterID: "chapter-1",
        activeStageID: "chapter-1-stage-1",
        completedStageIDs: [],
        claimedRewardStageIDs: [],
        pinnedMysteryEventIDs: [:]
    )

    public static let testSeed = Self.initial

    public init(
        activeChapterID: String,
        activeStageID: String?,
        completedStageIDs: Set<String>,
        claimedRewardStageIDs: Set<String>,
        pinnedMysteryEventIDs: [String: String] = [:]
    ) {
        self.activeChapterID = activeChapterID
        self.activeStageID = activeStageID
        self.completedStageIDs = completedStageIDs
        self.claimedRewardStageIDs = claimedRewardStageIDs
        self.pinnedMysteryEventIDs = pinnedMysteryEventIDs
    }
}
