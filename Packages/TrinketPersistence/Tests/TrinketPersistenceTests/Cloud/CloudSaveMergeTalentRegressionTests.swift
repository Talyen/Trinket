import Foundation
import Testing
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeTalentRegressionTests {
    @Test(arguments: [true, false], [true, false])
    @MainActor func `talent reset survives unrelated cloud progress and disk reload`(
        resetIncoming: Bool, resetMoreRecent: Bool,
    ) throws {
        var base = PlayerSave.fresh
        base.roster.progressions["knight"] = .at(level: 4)
        base.roster.unlockedTalents["knight"] = ["knight_block_t1_1", "knight_holy_t1_1"]
        let resetContext = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(base, to: resetContext.storeURL())
        let store = try resetContext.makeReloadedStore()
        #expect(store.mutateRoster { $0.resetTalents(for: "knight") })
        var reset = try resetContext.makeReloadedStore().currentSave
        #expect(reset.roster.unlockedTalents(for: "knight").isEmpty)
        reset.modifiedAt = Date(timeIntervalSince1970: resetMoreRecent ? 3 : 2)
        var progressed = base
        progressed.roster.gold += 17
        progressed.modifiedAt = Date(timeIntervalSince1970: resetMoreRecent ? 2 : 3)

        let merged = CloudSaveMerge.merge(
            incoming: resetIncoming ? reset : progressed,
            existing: resetIncoming ? progressed : reset,
            base: base, preferIncoming: true,
        )
        #expect(merged.roster.unlockedTalents(for: "knight").isEmpty)
        let mergedContext = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(merged, to: mergedContext.storeURL())
        let reloaded = try mergedContext.makeReloadedStore()
        #expect(reloaded.roster.unlockedTalents(for: "knight").isEmpty)
        #expect(reloaded.roster.availableTalentPoints(for: "knight") == 2)
        #expect(reloaded.roster.gold == progressed.roster.gold)
    }

    @Test func `reset removes shared talents while concurrent purchases remain`() {
        var base = PlayerSave.fresh
        base.roster.unlockedTalents["knight"] = ["knight_block_t1_1"]
        var reset = base
        reset.roster.resetTalents(for: "knight")
        var purchased = base
        purchased.roster.unlockedTalents["knight", default: []].insert("knight_holy_t1_1")

        let merged = CloudSaveMerge.merge(incoming: reset, existing: purchased, base: base, preferIncoming: false)
        #expect(merged.roster.unlockedTalents(for: "knight") == ["knight_holy_t1_1"])
    }

    @Test(arguments: [true, false])
    func `independent talent purchases union with and without a shared base`(sharedBase: Bool) {
        let base = PlayerSave.fresh
        var first = base
        first.roster.unlockedTalents["knight"] = ["knight_block_t1_1"]
        var second = base
        second.roster.unlockedTalents["knight"] = ["knight_holy_t1_1"]

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: sharedBase ? base : nil, preferIncoming: true)
        #expect(merged.roster.unlockedTalents(for: "knight") == ["knight_block_t1_1", "knight_holy_t1_1"])
    }
}
