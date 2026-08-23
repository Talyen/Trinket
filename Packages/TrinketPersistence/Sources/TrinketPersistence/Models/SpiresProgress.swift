import Foundation
import TrinketContent

/// Persistent progress for Spires climbs.
public struct PlayerSpiresState: Equatable, Sendable {
    /// Highest cleared floor per Spire (0 = none cleared).
    public var highestClearedFloorBySpireID: [String: Int]

    public init(highestClearedFloorBySpireID: [String: Int] = [:]) {
        self.highestClearedFloorBySpireID = highestClearedFloorBySpireID
    }

    public static let freshStart = Self()
    public static let testSeed = Self()

    public func highestClearedFloor(for spireID: String) -> Int {
        highestClearedFloorBySpireID[spireID] ?? 0
    }

    public func activeFloor(for spireID: String, floorCount: Int) -> Int {
        min(highestClearedFloor(for: spireID) + 1, max(floorCount, 1))
    }

    public func isFloorUnlocked(_ floor: Int, spireID: String, floorCount: Int) -> Bool {
        floor >= 1 && floor <= activeFloor(for: spireID, floorCount: floorCount)
    }

    public func isFloorCleared(_ floor: Int, spireID: String) -> Bool {
        floor <= highestClearedFloor(for: spireID)
    }

    /// True only for the next uncleared floor in the climb (one-clear tower).
    public func isFloorStartable(_ floor: Int, spireID: String) -> Bool {
        floor == highestClearedFloor(for: spireID) + 1
    }

    /// Advances highest cleared floor only for the next sequential floor.
    /// Replays (`floor <= current`) are no-ops. Skips are ignored.
    @discardableResult
    public mutating func markFloorCleared(_ floor: Int, spireID: String) -> Bool {
        let current = highestClearedFloor(for: spireID)
        if floor == current + 1 {
            highestClearedFloorBySpireID[spireID] = floor
            return true
        }
        return false
    }
}
