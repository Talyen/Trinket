import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct EffectRemovalTests {
    @Test(arguments: [false, true])
    func `random Purge preserves seeded selection survivor order and the subsequent random stream`(preservingBlock: Bool) {
        let effects = [Effect.thorns(2), .burn(3), .shield(.block, 4), .evadeNextHit, .poison(5), .shield(.block, 6)]
            .enumerated().map { ActiveEffect(id: $0.offset, effect: $0.element, remainingTurns: 0) }
        for count in [0, 1, 3, Int.max] {
            var expected = effects
            var expectedRNG = SeededRandomNumberGenerator(seed: 42)
            var expectedRemoved: [ActiveEffect] = []
            // The selection contract draws from the remaining buffs in their original order.
            for _ in 0 ..< min(count, effects.count) {
                let candidates = expected.indices.filter {
                    expected[$0].effect.isRemovableBuff && !(preservingBlock && expected[$0].effect.kind == .shield)
                }
                guard let index = candidates.randomElement(using: &expectedRNG) else { break }
                expectedRemoved.append(expected.remove(at: index))
            }
            var actual = effects
            var actualRNG = SeededRandomNumberGenerator(seed: 42)
            let removed = EffectRemoval.removeBuffs(from: &actual, count: count, preservingBlock: preservingBlock, using: &actualRNG)

            #expect(removed == expectedRemoved)
            #expect(actual == expected)
            #expect(actualRNG.next() == expectedRNG.next())
        }
    }

    @Test func `random Cleanse preserves stack order and the subsequent random stream`() {
        var effects = [Effect.thorns(2), .burn(3), .shield(.block, 4), .poison(5), .bleed(6)]
            .enumerated().map { ActiveEffect(id: $0.offset, effect: $0.element, remainingTurns: 2) }
        var expected = effects
        var actualRNG = SeededRandomNumberGenerator(seed: 42)
        var expectedRNG = actualRNG
        // Include the empty selection: it must not spend the next combat roll.
        for _ in 0 ..< 4 {
            let candidates = expected.indices.filter { expected[$0].effect.isRemovableDebuff }
            let expectedRemoved = candidates.randomElement(using: &expectedRNG).map { expected.remove(at: $0) }
            let removed = EffectRemoval.removeRandomDebuff(from: &effects, using: &actualRNG)
            #expect(removed == expectedRemoved)
            #expect(effects == expected)
        }
        #expect(actualRNG.next() == expectedRNG.next())
    }

    @Test func `selected Cleanse preserves keyword and stack order for reflection`() {
        var effects = [Effect.poison(2), .burn(3), .thorns(4), .poison(5), .bleed(6)]
            .enumerated().map { ActiveEffect(id: $0.offset, effect: $0.element, remainingTurns: 2) }
        let removed = EffectRemoval.removeDebuffs(from: &effects, keywords: [.poison, .burn])

        #expect(removed.map(\.id) == [1, 0, 3])
        #expect(effects.map(\.id) == [2, 4])
    }
}
