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

    public static var fresh: PlayerSave {
        PlayerSave(
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

    public static var testSeed: PlayerSave {
        PlayerSave(
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
    public static var unlockedAll: PlayerSave {
        var roster = PlayerRosterState.freshStart
        roster.unlockAllCombatants(atLevel: 20)
        roster.gold = PlayerRosterState.maxGoldBalance

        var journey = JourneyProgressState.initial
        journey.completeChapter("chapter-1")

        return PlayerSave(
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

extension PlayerSave: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case modifiedAt
        case sessionGeneration
        case journey
        case roster
        case inventory
        case homestead
        case spires
        case aspects
        case labyrinth
        case corruptionAltarCooldownRemaining
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        sessionGeneration = try container.decodeIfPresent(UInt64.self, forKey: .sessionGeneration) ?? 0
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        let wireInventory = try container.decode(WireInventoryState.self, forKey: .inventory)
        inventory = wireInventory.inventory()
        let wireRoster = try container.decode(WireRosterState.self, forKey: .roster)
        roster = wireRoster.roster(inventory: inventory)
        homestead = try container.decodeIfPresent(WireHomesteadState.self, forKey: .homestead)?
            .homestead() ?? .freshStart
        spires = try container.decodeIfPresent(
            WireSpiresState.self,
            forKey: .spires
        )?.spires() ?? container.decodeIfPresent(
            WireSpiresState.self,
            forKey: .aspects
        )?.spires() ?? .freshStart
        labyrinth = try container.decodeIfPresent(
            WireLabyrinthState.self,
            forKey: .labyrinth
        )?.labyrinth() ?? .freshStart
        corruptionAltarCooldownRemaining = try container.decodeIfPresent(
            Int.self,
            forKey: .corruptionAltarCooldownRemaining
        ) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(sessionGeneration, forKey: .sessionGeneration)
        try container.encode(journey, forKey: .journey)
        try container.encode(WireRosterState(roster), forKey: .roster)
        try container.encode(WireInventoryState(inventory), forKey: .inventory)
        try container.encode(WireHomesteadState(homestead), forKey: .homestead)
        try container.encode(WireSpiresState(spires), forKey: .spires)
        try container.encode(WireLabyrinthState(labyrinth), forKey: .labyrinth)
        try container.encode(corruptionAltarCooldownRemaining, forKey: .corruptionAltarCooldownRemaining)
    }
}
