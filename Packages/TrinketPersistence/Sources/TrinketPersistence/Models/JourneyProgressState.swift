import Foundation

public struct JourneyProgressState: Codable, Equatable, Sendable {
    public var activeChapterID: String
    public var activeStageID: String?
    public var completedStageIDs: Set<String>
    public var claimedRewardStageIDs: Set<String>
    public var lastCompletedStageID: String?
    /// Seeded/opened journey mystery event per stage (Labyrinth-style pin).
    public var pinnedMysteryEventIDs: [String: String]

    public static let initial = Self(
        activeChapterID: "chapter-1",
        activeStageID: "chapter-1-stage-1",
        completedStageIDs: [],
        claimedRewardStageIDs: [],
        lastCompletedStageID: nil,
        pinnedMysteryEventIDs: [:]
    )

    public static let testSeed = Self.initial

    public init(
        activeChapterID: String,
        activeStageID: String?,
        completedStageIDs: Set<String>,
        claimedRewardStageIDs: Set<String>,
        lastCompletedStageID: String?,
        pinnedMysteryEventIDs: [String: String] = [:]
    ) {
        self.activeChapterID = activeChapterID
        self.activeStageID = activeStageID
        self.completedStageIDs = completedStageIDs
        self.claimedRewardStageIDs = claimedRewardStageIDs
        self.lastCompletedStageID = lastCompletedStageID
        self.pinnedMysteryEventIDs = pinnedMysteryEventIDs
    }

    private enum CodingKeys: String, CodingKey {
        case activeChapterID
        case activeStageID
        case completedStageIDs
        case claimedRewardStageIDs
        case lastCompletedStageID
        case pinnedMysteryEventIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeChapterID = try container.decode(String.self, forKey: .activeChapterID)
        activeStageID = try container.decodeIfPresent(String.self, forKey: .activeStageID)
        completedStageIDs = try container.decode(Set<String>.self, forKey: .completedStageIDs)
        claimedRewardStageIDs = try container.decode(Set<String>.self, forKey: .claimedRewardStageIDs)
        lastCompletedStageID = try container.decodeIfPresent(String.self, forKey: .lastCompletedStageID)
        pinnedMysteryEventIDs = try container.decodeIfPresent(
            [String: String].self,
            forKey: .pinnedMysteryEventIDs
        ) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeChapterID, forKey: .activeChapterID)
        try container.encodeIfPresent(activeStageID, forKey: .activeStageID)
        try container.encode(completedStageIDs, forKey: .completedStageIDs)
        try container.encode(claimedRewardStageIDs, forKey: .claimedRewardStageIDs)
        try container.encodeIfPresent(lastCompletedStageID, forKey: .lastCompletedStageID)
        if !pinnedMysteryEventIDs.isEmpty {
            try container.encode(pinnedMysteryEventIDs, forKey: .pinnedMysteryEventIDs)
        }
    }
}
