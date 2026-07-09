import Foundation

/// Persistent progress for Aspects climbs.
public struct PlayerAspectsState: Equatable, Sendable {
    /// Highest cleared floor per Aspect (0 = none cleared).
    public var highestClearedFloorByAspectID: [String: Int]

    public init(highestClearedFloorByAspectID: [String: Int] = [:]) {
        self.highestClearedFloorByAspectID = highestClearedFloorByAspectID
    }

    public static let freshStart = PlayerAspectsState()
    public static let testSeed = PlayerAspectsState()

    public func highestClearedFloor(for aspectID: String) -> Int {
        highestClearedFloorByAspectID[aspectID] ?? 0
    }

    public func activeFloor(for aspectID: String, floorCount: Int) -> Int {
        min(highestClearedFloor(for: aspectID) + 1, max(floorCount, 1))
    }

    public func isFloorUnlocked(_ floor: Int, aspectID: String, floorCount: Int) -> Bool {
        floor >= 1 && floor <= activeFloor(for: aspectID, floorCount: floorCount)
    }

    public func isFloorCleared(_ floor: Int, aspectID: String) -> Bool {
        floor <= highestClearedFloor(for: aspectID)
    }

    public mutating func markFloorCleared(_ floor: Int, aspectID: String) {
        let current = highestClearedFloor(for: aspectID)
        if floor > current {
            highestClearedFloorByAspectID[aspectID] = floor
        }
    }
}

public extension PlayerAspectsState {
    var current: PlayerAspectsState {
        get { self }
        set { self = newValue }
    }
}
