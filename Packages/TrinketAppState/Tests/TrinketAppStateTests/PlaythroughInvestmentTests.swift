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

    @Test(arguments: [false, true])
    func `bow transition journals replay and resume after committed quiver removal`(reloadBetweenCommands: Bool) async throws {
        let output = try SaveTestSupport.makeTempDirectory(prefix: "PlaythroughBowTransition")
        print("Playthrough bow verification evidence: \(output.path)")
        var scenario = PlaythroughScenario()
        scenario.fullAccess = true
        let source = try PlaythroughCareer(scenario: scenario, output: output.appendingPathComponent("source"))
        defer { source.close() }
        let replay = try PlaythroughCareer(scenario: scenario, output: output.appendingPathComponent("replay"))
        defer { replay.close() }
        let fixture = try await prepareBowFixture([source, replay])
        let (hero, other) = (fixture.hero, fixture.other)
        let (bow, quiver, melee, reserved) = (fixture.bow, fixture.quiver, fixture.melee, fixture.reserved)
        let prefix = source.sequence
        // Preserve the old default-slot journal action alongside explicit-slot actions.
        try await source.perform(.equip(combatant: hero.id, item: bow.id))
        try await source.perform(.equipInSlot(combatant: hero.id, item: quiver.id, slot: .secondaryWeapon))
        if reloadBetweenCommands {
            let upgrade = try #require(SimulationEquipmentPolicy.nextUpgrade(
                for: hero, inventory: source.store.inventory.items, loadout: source.store.roster.equipmentLoadout(for: hero),
                reservedItemIDs: [reserved.id],
            ))
            let slot = try #require(upgrade.unequipFirst)
            try await source.perform(.unequipInSlot(combatant: hero.id, slot: slot))
            let intermediate = source.snapshot
            try await source.perform(.reopen)
            #expect(source.snapshot == intermediate)
            #expect(source.store.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == bow.id)
            #expect(source.store.roster.equipmentLoadout(for: hero).itemID(for: .secondaryWeapon) == nil)
        }
        try await source.invest()
        #expect(source.store.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == melee.id)
        #expect(source.store.roster.equipmentLoadout(for: hero).itemID(for: .secondaryWeapon) == nil)
        #expect(source.store.inventory.items.contains { $0.id == quiver.id })
        #expect(source.store.roster.equipmentLoadout(for: other).itemID(for: .weapon) == reserved.id)
        let changes = source.summary.equipmentChanges
        let sequence = source.sequence
        try await source.invest()
        #expect(source.sequence == sequence)
        try await source.perform(.reopen)
        let expected = source.snapshot
        source.close()
        try await replayBowSuffix(
            source: output.appendingPathComponent("source"),
            prefix: prefix,
            meleeID: melee.id,
            output: output,
            replay: replay,
        )
        #expect(replay.summary.termination == "replayedRecordedActions")
        #expect(replay.snapshot == expected)
        #expect(replay.summary.equipmentChanges == changes)
        #expect(replay.summary.reloads == source.summary.reloads)
    }

    private struct BowFixture {
        let hero: Combatant
        let other: Combatant
        let bow: InventoryItem
        let quiver: InventoryItem
        let melee: InventoryItem
        let reserved: InventoryItem
    }

    private func prepareBowFixture(_ careers: [PlaythroughCareer]) async throws -> BowFixture {
        for career in careers {
            try await career.perform(.starterHero("knight"))
            try await career.perform(.starterCompanion("wolf"))
        }
        let source = careers[0]
        let hero = source.store.roster.activeHero
        let other = try #require(GameContent.heroes.first { $0.id != hero.id })
        var random = SeededRandomNumberGenerator(seed: 20261025)
        let bias = Set(hero.abilities.flatMap(\.keywords))
        func item(_ id: String, baseID: String, rarity: Rarity, count: Int) throws -> InventoryItem {
            try ItemGenerator().generate(
                id: id,
                baseType: #require(GameContent.itemBaseType(matching: baseID)),
                rarity: rarity,
                fixedAffixCount: count,
                keywordBias: bias,
                requireBuildAlignment: true,
                using: &random,
            )
        }
        let bow = try item("fixture-bow", baseID: "shortbow", rarity: .basic, count: 1)
        let quiver = try item("fixture-quiver", baseID: "quiver", rarity: .basic, count: 1)
        let melee = try item("fixture-z-melee", baseID: "maul", rarity: .astral, count: 4)
        let reserved = try item("fixture-a-reserved", baseID: "maul", rarity: .astral, count: 4)
        // Both replay inputs start from the same explicit correctness fixture.
        for career in careers {
            try #require(career.store.persistFixtureBatch(logging: "Bow transition coverage") { save in
                save.inventory.items = [bow, quiver, melee, reserved]
                save.roster.gold = 0
                save.roster.unlockedHeroIDs.insert(other.id)
                save.roster.setEquipmentLoadout(.init(itemIDsBySlot: [.weapon: reserved.id]), for: other)
            })
        }
        #expect(source.snapshot == careers[1].snapshot)
        return BowFixture(hero: hero, other: other, bow: bow, quiver: quiver, melee: melee, reserved: reserved)
    }

    private func replayBowSuffix(source: URL, prefix: Int, meleeID: String, output: URL, replay: PlaythroughCareer) async throws {
        let records = try Data(contentsOf: source.appendingPathComponent("actions.jsonl"))
            .split(separator: 0x0A).map { try PlaythroughJournal.decodeRecord(Data($0)) }.filter { $0.sequence > prefix }
        let committed = records.filter { $0.result == "committed" }
        let removal = try #require(committed.firstIndex {
            if case .unequipInSlot = $0.action {
                true
            } else {
                false
            }
        })
        let equip = try #require(committed.firstIndex {
            if case let .equipInSlot(_, id, _) = $0.action {
                id == meleeID
            } else {
                false
            }
        })
        #expect(removal < equip)
        let input = output.appendingPathComponent("replay-input")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        var journal = Data()
        for record in records {
            try journal.append(JSONEncoder().encode(record)); journal.append(0x0A)
        }
        try journal.write(to: input.appendingPathComponent("actions.jsonl"))
        try await PlaythroughSweepTests().replay(replay, source: input)
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
