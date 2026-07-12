import Foundation
import TrinketContent

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

    /// True only for the next uncleared floor in the climb (one-clear tower).
    public func isFloorStartable(_ floor: Int, aspectID: String) -> Bool {
        floor == highestClearedFloor(for: aspectID) + 1
    }

    /// Advances highest cleared floor only for the next sequential floor.
    /// Replays (`floor <= current`) are no-ops. Skips are ignored.
    @discardableResult
    public mutating func markFloorCleared(_ floor: Int, aspectID: String) -> Bool {
        let current = highestClearedFloor(for: aspectID)
        if floor == current + 1 {
            highestClearedFloorByAspectID[aspectID] = floor
            return true
        }
        return false
    }

    /// Clears every Aspect climb so all Aspects are unlocked.
    public mutating func unlockAll(aspects: [AspectDefinition] = GameContent.aspects) {
        highestClearedFloorByAspectID = Dictionary(
            uniqueKeysWithValues: aspects.map { ($0.id.rawValue, $0.floorCount) }
        )
    }
}

public extension PlayerAspectsState {
    var current: PlayerAspectsState {
        get { self }
        set { self = newValue }
    }
}
