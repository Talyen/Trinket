import Foundation
import TrinketContent

public struct PlayerSpiresState: Equatable, Sendable {
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

    public func isFloorStartable(_ floor: Int, spireID: String, floorCount: Int) -> Bool {
        floor == highestClearedFloor(for: spireID) + 1 && floor <= floorCount
    }

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
