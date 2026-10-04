import Testing
import TrinketCore
@testable import TrinketContent

struct CorruptionAltarPickTests {
    @Test func `corruption altar exists with two choices`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        #expect(event.choices.count == 2)
        #expect(event.choices.contains { $0.effects.contains(.corruptItem) })
        #expect(event.choices.contains { $0.effects.contains(.leave) })
    }

    @Test(arguments: [(false, true, 0), (true, true, 4), (true, false, 0)])
    func `pick excludes altar even on a winning roll when ineligible`(allowsAltar: Bool, hasTarget: Bool, cooldown: Int) throws {
        var rng = try generator(forAltarRoll: 1)
        let event = GameContent.pickMysteryEvent(
            context: MysteryEventPickContext(
                allowsCorruptionAltar: allowsAltar,
                hasEligibleCorruptTarget: hasTarget,
                corruptionAltarCooldownRemaining: cooldown,
            ), using: &rng,
        )
        #expect(event.id != GameContent.corruptionAltarEventID)
    }

    @Test(arguments: [25, 26])
    func `ready altar respects the chance boundary`(roll: Int) throws {
        var rng = try generator(forAltarRoll: roll)
        let event = GameContent.pickMysteryEvent(
            context: MysteryEventPickContext(
                allowsCorruptionAltar: true, hasEligibleCorruptTarget: true, corruptionAltarCooldownRemaining: 0,
            ), using: &rng,
        )
        #expect((event.id == GameContent.corruptionAltarEventID) == (roll == 25))
    }

    @Test func `journey mystery resolve is stable and prefers authored`() throws {
        let context = MysteryEventPickContext.excludingCorruptionAltar
        let stageID = "chapter-1-stage-5"
        let first = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            context: context,
        )
        let second = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            context: context,
        )
        #expect(first.id == second.id)
        #expect(first.id != GameContent.corruptionAltarEventID)
        #expect(
            GameContent.encounterSeed(11, salt: "journey-mystery-\(stageID)")
                != GameContent.encounterSeed(12, salt: "journey-mystery-\(stageID)"),
        )

        let authored = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let forced = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: authored,
            context: context,
        )
        #expect(forced.id == "mana-berries")

        let pinned = GameContent.resolveJourneyMysteryEvent(
            stageID: stageID,
            worldSeed: 11,
            authored: nil,
            pinnedEventID: "mana-berries",
            context: context,
        )
        #expect(pinned.id == "mana-berries")

        if let artID = first.artID {
            #expect(
                ArtCatalog.encounterArtByID[artID] != nil
                    || ArtCatalog.backgroundArtByID[artID] != nil,
            )
        }
    }

    @Test func `seeded non altar pick stable when altar eligibility flips`() throws {
        var withoutAltarRNG = try generator(forAltarRoll: 26)
        var withAltarRNG = withoutAltarRNG
        let withoutAltar = GameContent.pickMysteryEvent(
            context: .excludingCorruptionAltar, using: &withoutAltarRNG,
        )
        let withAltarChance = GameContent.pickMysteryEvent(
            context: MysteryEventPickContext(
                allowsCorruptionAltar: true, hasEligibleCorruptTarget: true, corruptionAltarCooldownRemaining: 0,
            ), using: &withAltarRNG,
        )
        #expect(withoutAltar.id == withAltarChance.id)
        #expect(withoutAltarRNG.next() == withAltarRNG.next())
    }

    private func generator(forAltarRoll roll: Int) throws -> SeededRandomNumberGenerator {
        let seed = try #require((UInt64(1) ... 10000).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return Int.random(in: 1 ... 100, using: &rng) == roll
        })
        return SeededRandomNumberGenerator(seed: seed)
    }
}
