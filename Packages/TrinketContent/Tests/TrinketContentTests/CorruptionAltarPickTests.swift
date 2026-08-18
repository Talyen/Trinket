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
        for seed in UInt64(1) ... 40 {
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

    @Test func journeyMysteryResolveIsStableAndPrefersAuthored() throws {
        let context = MysteryEventPickContext.excludingCorruptionAltar
        let stageID = "chapter-1-stage-5"
        let first = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            context: context
        )
        let second = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            context: context
        )
        #expect(first.id == second.id)
        #expect(first.id != GameContent.corruptionAltarEventID)
        #expect(
            GameContent.encounterSeed(11, salt: "journey-mystery-\(stageID)")
                != GameContent.encounterSeed(12, salt: "journey-mystery-\(stageID)")
        )

        let authored = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let forced = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: authored,
            context: context
        )
        #expect(forced.id == "mana-berries")

        let pinned = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            pinnedEventID: "mana-berries",
            context: context
        )
        #expect(pinned.id == "mana-berries")

        if let artID = first.artID {
            #expect(
                ArtCatalog.encounterArtByID[artID] != nil
                    || ArtCatalog.backgroundArtByID[artID] != nil
            )
        }
    }

    @Test func seededNonAltarPickStableWhenAltarEligibilityFlips() {
        let ineligible = MysteryEventPickContext(
            allowsCorruptionAltar: true,
            hasEligibleCorruptTarget: false,
            corruptionAltarCooldownRemaining: 0
        )
        let eligible = MysteryEventPickContext(
            allowsCorruptionAltar: true,
            hasEligibleCorruptTarget: true,
            corruptionAltarCooldownRemaining: 0
        )

        var matchedNonAltar = false
        for seed in UInt64(1) ... 40 {
            var ineligibleRNG = SeededRandomNumberGenerator(seed: seed)
            var eligibleRNG = SeededRandomNumberGenerator(seed: seed)
            let withoutAltar = GameContent.pickMysteryEvent(
                context: ineligible,
                using: &ineligibleRNG
            )
            let withAltarChance = GameContent.pickMysteryEvent(
                context: eligible,
                using: &eligibleRNG
            )
            if withAltarChance.id == GameContent.corruptionAltarEventID {
                continue
            }
            #expect(withoutAltar.id == withAltarChance.id)
            matchedNonAltar = true
            break
        }
        #expect(matchedNonAltar)
    }
}
