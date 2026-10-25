import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@Suite(.serialized)
@MainActor
struct PlaythroughInvestmentTests {
    @Test func `investments upgrade persist secondary slots and retain other owners without cycling`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughInvestment")
        // SwiftData can retain SQLite handles beyond the career's lifetime.
        // Archive and remove this evidence only after the test worker exits.
        print("Playthrough verification evidence: \(output.path)")
        var scenario = PlaythroughScenario()
        scenario.fullAccess = true
        let career = try PlaythroughCareer(scenario: scenario, output: output)
        defer { career.close() }
        try await career.perform(.starterHero("knight"))
        try await career.perform(.starterCompanion("wolf"))
        let hero = career.store.roster.activeHero
        let companion = career.store.roster.activeCompanion
        let other = try #require(GameContent.companion(matching: "bear"))
        var random = SeededRandomNumberGenerator(seed: 20261025)
        let bias = Set(hero.abilities.flatMap(\.keywords))
        func item(_ id: String, baseID: String, rarity: Rarity, count: Int) throws -> InventoryItem {
            try ItemGenerator().generate(
                id: id, baseType: #require(GameContent.itemBaseType(matching: baseID)),
                rarity: rarity, fixedAffixCount: count, keywordBias: bias,
                requireBuildAlignment: true, using: &random,
            )
        }
        let weak = try item("fixture-weak", baseID: "plate_armor", rarity: .basic, count: 1)
        let strong = try item("fixture-strong", baseID: "plate_armor", rarity: .astral, count: 3)
        let accessories = try (0 ..< 3).map { try item("fixture-accessory-\($0)", baseID: "ruby_ring", rarity: .astral, count: 3) }
        let reserved = try item("fixture-reserved", baseID: "ruby_ring", rarity: .astral, count: 4)
        // A correctness fixture establishes every equipment branch, not pacing.
        try #require(career.store.persistFixtureBatch(logging: "Investment coverage") { save in
            save.inventory.items = [weak, strong] + accessories + [reserved]
            save.roster.gold = 0
            save.roster.unlockedCompanionIDs.insert(other.id)
            save.roster.setEquipmentLoadout(.init(itemIDsBySlot: [.accessory: reserved.id]), for: other)
        })
        // Old journals retain their original default-slot command semantics.
        try await career.perform(.equip(combatant: hero.id, item: weak.id))
        try await career.invest()
        let roster = career.store.roster
        #expect(roster.equipmentLoadout(for: hero).itemID(for: .armor) == strong.id)
        let accessoryIDs = Set([ItemSlot.accessory, .secondaryAccessory].compactMap {
            roster.equipmentLoadout(for: hero).itemID(for: $0)
        })
        #expect(accessoryIDs.count == 2)
        #expect(accessoryIDs.isSubset(of: Set(accessories.map(\.id))))
        #expect(roster.equipmentLoadout(for: companion).itemID(for: .accessory) != nil)
        #expect(roster.equipmentLoadout(for: other).itemID(for: .accessory) == reserved.id)
        let expected = career.snapshot
        let changes = career.summary.equipmentChanges
        let sequence = career.sequence
        try await career.invest()
        #expect(career.sequence == sequence)
        #expect(career.snapshot == expected)
        try await career.perform(.reopen)
        #expect(career.snapshot == expected)
        try await career.invest()
        #expect(career.summary.equipmentChanges == changes)
        #expect(career.snapshot == expected)
        #expect(career.summary.equipmentPolicyID == SimulationEquipmentPolicy.id)
    }

    @Test func `fresh earned equipment career replays every committed action and reload`() async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughInvestmentReplay")
        print("Playthrough verification evidence: \(output.path)")
        var scenario = PlaythroughScenario()
        scenario.attempts = 8
        let source = output.appendingPathComponent("source")
        let career = try PlaythroughCareer(scenario: scenario, output: source)
        let expected = try await career.run(reload: true)
        #expect(career.summary.termination == "completedObjective")
        #expect(career.summary.equipmentChanges > 0)
        #expect(career.summary.reloads == scenario.attempts)
        let records = try Data(contentsOf: source.appendingPathComponent("actions.jsonl"))
            .split(separator: 0x0A).map { try PlaythroughJournal.decodeRecord(Data($0)) }
        #expect(records.contains { record in
            if case .equipInSlot = record.action {
                return record.result == "committed"
            }
            return false
        })
        let replay = try PlaythroughCareer(scenario: scenario, output: output.appendingPathComponent("replay"))
        defer { replay.close() }
        try await PlaythroughSweepTests().replay(replay, source: source)
        #expect(replay.summary.termination == "replayedRecordedActions")
        #expect(replay.snapshot == expected)
        #expect(replay.summary.equipmentChanges == career.summary.equipmentChanges)
        #expect(replay.summary.reloads == career.summary.reloads)
    }
}
