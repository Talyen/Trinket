import Foundation
import TrinketContent
import TrinketCore

public struct PlayerSave: Equatable, Sendable {
    public static let currentSchemaVersion = 16

    /// Schema milestones referenced by load-time field mappings. When a save
    /// field changes shape, add the matching milestone here and bump
    /// `currentSchemaVersion`; the mappings in `PlayerSaveRoot+Mapping` and
    /// `RosterHydration` read these gates during decode.
    public enum Schema {
        /// 13→14 renamed equipment slots ("Trinket" → `.accessory`, etc.).
        public static let renamedItemSlots = 14
        /// 15→16 introduced the persisted starter-selection phase.
        public static let persistedStarterSelection = 16
    }

    public static let corruptionAltarCooldownAfterEncounter = 6
    /// Fixed seed for `testSeed` fixtures so Persistence tests stay deterministic.
    public static let testWorldSeed: UInt64 = 0x5445_5354

    public var schemaVersion: Int
    public var modifiedAt: Date
    public var sessionGeneration: UInt64
    /// Save-scoped entropy mixed into generated shops, loot, mysteries, and maps.
    public var worldSeed: UInt64
    public var starterSelection: StarterSelectionState
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
            worldSeed: makeWorldSeed(),
            starterSelection: .fresh,
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
            worldSeed: testWorldSeed,
            starterSelection: .complete,
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
        roster.gold = 900

        var journey = JourneyProgressState.initial
        journey.completeChapter("chapter-1")

        return Self(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            worldSeed: makeWorldSeed(),
            starterSelection: .complete,
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
        worldSeed: UInt64 = 0,
        starterSelection: StarterSelectionState = .complete,
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
        self.worldSeed = worldSeed
        self.starterSelection = starterSelection
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
        self.spires = spires
        self.labyrinth = labyrinth
        self.corruptionAltarCooldownRemaining = max(0, corruptionAltarCooldownRemaining)
    }

    public static func makeWorldSeed() -> UInt64 {
        var seed: UInt64
        repeat {
            seed = UInt64.random(in: .min ... .max)
        } while seed == 0 || seed == LabyrinthGenerator.fallbackWorldSeed
        return seed
    }

    @discardableResult
    public mutating func grantGold(_ amount: Int, at date: Date = Date()) -> Int {
        guard amount > 0 else { return 0 }
        homestead.settleProduction(at: date, roster: roster)
        let balanceBefore = roster.gold
        let reserved = Int(ceil(homestead.pendingProduction[.gold, default: 0]))
        let available = max(0, PlayerRosterState.maxGoldBalance - roster.gold - reserved)
        roster.grantGold(min(amount, available))
        return roster.gold - balanceBefore
    }

    @discardableResult
    public mutating func applyGoldDelta(_ amount: Int, at date: Date = Date()) -> Int {
        if amount >= 0 {
            return grantGold(amount, at: date)
        }
        homestead.settleProduction(at: date, roster: roster)
        let balanceBefore = roster.gold
        _ = roster.spendGold(min(-amount, roster.gold))
        return roster.gold - balanceBefore
    }

    /// Settles production before granting materials and returns the amounts accepted.
    @discardableResult
    public mutating func grantMaterials(
        _ rewards: [ResourceAmount],
        at date: Date = Date()
    ) -> [ResourceAmount] {
        guard !rewards.isEmpty else { return [] }
        homestead.settleProduction(at: date, roster: roster)
        let balancesBefore = homestead.resources
        homestead.grant(rewards)

        var resourceOrder: [HomesteadResource] = []
        var seenResources = Set<HomesteadResource>()
        for reward in rewards where reward.resource != .gold && seenResources.insert(reward.resource).inserted {
            resourceOrder.append(reward.resource)
        }
        return resourceOrder.compactMap { resource in
            let granted = homestead.resources[resource, default: 0] - balancesBefore[resource, default: 0]
            guard granted > 0 else { return nil }
            return ResourceAmount(resource, granted)
        }
    }
}
