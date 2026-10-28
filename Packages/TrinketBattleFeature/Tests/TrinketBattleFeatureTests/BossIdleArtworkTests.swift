import Testing
@testable import TrinketBattleFeature

struct BossIdleArtworkTests {
    @Test func `shuffled rounds play every clip without adjacent repeats`() {
        for count in [3, 5] {
            var order = BossIdleOrder(count: count)
            let selections = (0 ..< count * 30).compactMap { _ in order.next() }
            #expect(selections.count == count * 30)
            for (previous, next) in zip(selections, selections.dropFirst()) {
                #expect(previous != next)
            }
            for start in stride(from: 0, to: selections.count, by: count) {
                #expect(Set(selections[start ..< start + count]) == Set(0 ..< count))
            }
        }
    }

    @Test func `every boss has its complete bundled clip set`() {
        for (id, count) in [
            ("the_blight_treant", 3), ("the_forge_golem", 3), ("the_frostwarden", 3),
            ("the_iron_bear", 3), ("the_blood_countess", 5), ("the_seraph", 3), ("the_stone_titan", 3),
        ] {
            #expect(BossIdleCatalog.clips(for: id)?.count == count)
        }
        #expect(BossIdleCatalog.clips(for: "slime") == nil)
    }
}
