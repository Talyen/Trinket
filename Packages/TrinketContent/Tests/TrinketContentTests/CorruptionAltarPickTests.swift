import Testing
import TrinketCore
@testable import TrinketContent

struct CorruptionAltarPickTests {
    @Test func corruptionAltarExistsWithTwoChoices() throws {
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        #expect(event.choices.count == 2)
        #expect(event.choices.contains { $0.effects.contains(.corruptItem) })
        #expect(event.choices.contains { $0.effects.contains(.leave) })
        #expect(event.artID == "destination-corruption-altar")
    }

    @Test func pickExcludesAltarOnCooldownOrChapterOne() {
        var rng = SeededRandomNumberGenerator(seed: 11)
        for _ in 0 ..< 30 {
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: false,
                    hasEligibleCorruptTarget: true,
                    corruptionAltarCooldownRemaining: 0
                ),
                using: &rng
            )
            #expect(event.id != GameContent.corruptionAltarEventID)
        }

        rng = SeededRandomNumberGenerator(seed: 12)
        for _ in 0 ..< 30 {
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: true,
                    hasEligibleCorruptTarget: true,
                    corruptionAltarCooldownRemaining: 4
                ),
                using: &rng
            )
            #expect(event.id != GameContent.corruptionAltarEventID)
        }

        rng = SeededRandomNumberGenerator(seed: 13)
        for _ in 0 ..< 30 {
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: true,
                    hasEligibleCorruptTarget: false,
                    corruptionAltarCooldownRemaining: 0
                ),
                using: &rng
            )
            #expect(event.id != GameContent.corruptionAltarEventID)
        }
    }

    @Test func pickCanSelectAltarWhenReady() {
        var hits = 0
        for seed in UInt64(1) ... 200 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: true,
                    hasEligibleCorruptTarget: true,
                    corruptionAltarCooldownRemaining: 0
                ),
                using: &rng
            )
            if event.id == GameContent.corruptionAltarEventID {
                hits += 1
            }
        }
        #expect(hits > 0)
    }
}
