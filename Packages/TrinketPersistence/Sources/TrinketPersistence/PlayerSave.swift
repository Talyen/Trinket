import Foundation

public struct PlayerSave: Equatable, Sendable {
    public static let currentSchemaVersion = 12
    public static let corruptionAltarCooldownAfterEncounter = 6

    public var schemaVersion: Int
    public var modifiedAt: Date
    public var sessionGeneration: UInt64
    public var journey: JourneyProgressState
    public var roster: PlayerRosterState
    public var inventory: PlayerInventoryState
    public var homestead: PlayerHomesteadState
    public var spires: PlayerSpiresState
    public var labyrinth: PlayerLabyrinthState
    /// Mysteries remaining before Corruption Altar can roll again at full weight.
    public var corruptionAltarCooldownRemaining: Int

    public static var fresh: Self {
        Self(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            homestead: .freshStart,
            spires: .freshStart,
            labyrinth: .freshStart
        )
    }

    public static var testSeed: Self {
        Self(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .testSeed,
            roster: .testSeed,
            inventory: .testSeed,
            homestead: .testSeed,
            spires: .testSeed,
            labyrinth: .testSeed
        )
    }

    /// Unlocked roster save for local development and Simulator testing.
    /// Clears Chapter 1 so Modes unlock; leaves later chapters, Spires, and Labyrinth uncleared.
    public static var unlockedAll: Self {
        var roster = PlayerRosterState.freshStart
        roster.unlockAllCombatants(atLevel: 20)
        roster.gold = PlayerRosterState.maxGoldBalance

        var journey = JourneyProgressState.initial
        journey.completeChapter("chapter-1")

        return Self(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: journey,
            roster: roster,
            inventory: .testSeed,
            homestead: .developerMaxed,
            spires: .freshStart,
            labyrinth: .freshStart
        )
    }

    public init(
        schemaVersion: Int,
        modifiedAt: Date,
        sessionGeneration: UInt64 = 0,
        journey: JourneyProgressState,
        roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        homestead: PlayerHomesteadState = .freshStart,
        spires: PlayerSpiresState = .freshStart,
        labyrinth: PlayerLabyrinthState = .freshStart,
        corruptionAltarCooldownRemaining: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.sessionGeneration = sessionGeneration
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
        self.spires = spires
        self.labyrinth = labyrinth
        self.corruptionAltarCooldownRemaining = max(0, corruptionAltarCooldownRemaining)
    }
}
