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

    private struct AltarIneligibleCase: Sendable {
        let allowsAltar: Bool
        let hasEligibleCorruptTarget: Bool
        let cooldownRemaining: Int

        static let altarDisallowed = Self(allowsAltar: false, hasEligibleCorruptTarget: true, cooldownRemaining: 0)
        static let altarOnCooldown = Self(allowsAltar: true, hasEligibleCorruptTarget: true, cooldownRemaining: 4)
        static let noCorruptTarget = Self(allowsAltar: true, hasEligibleCorruptTarget: false, cooldownRemaining: 0)
    }

    @Test(arguments: [Self.AltarIneligibleCase.altarDisallowed, .altarOnCooldown, .noCorruptTarget])
    private func `pick excludes altar when ineligible`(_ testCase: AltarIneligibleCase) {
        var rng = SeededRandomNumberGenerator(seed: UInt64(11 + testCase.cooldownRemaining))
        for _ in 0 ..< 30 {
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: testCase.allowsAltar,
                    hasEligibleCorruptTarget: testCase.hasEligibleCorruptTarget,
                    corruptionAltarCooldownRemaining: testCase.cooldownRemaining,
                ),
                using: &rng,
            )
            #expect(event.id != GameContent.corruptionAltarEventID)
        }
    }

    @Test func `pick can select altar when ready`() {
        var hits = 0
        for seed in UInt64(1) ... 40 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let event = GameContent.pickMysteryEvent(
                context: MysteryEventPickContext(
                    allowsCorruptionAltar: true,
                    hasEligibleCorruptTarget: true,
                    corruptionAltarCooldownRemaining: 0,
                ),
                using: &rng,
            )
            if event.id == GameContent.corruptionAltarEventID {
                hits += 1
            }
        }
        #expect(hits > 0)
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

    @Test func `seeded non altar pick stable when altar eligibility flips`() {
        let ineligible = MysteryEventPickContext(
            allowsCorruptionAltar: true,
            hasEligibleCorruptTarget: false,
            corruptionAltarCooldownRemaining: 0,
        )
        let eligible = MysteryEventPickContext(
            allowsCorruptionAltar: true,
            hasEligibleCorruptTarget: true,
            corruptionAltarCooldownRemaining: 0,
        )

        var matchedNonAltar = false
        for seed in UInt64(1) ... 40 {
            var ineligibleRNG = SeededRandomNumberGenerator(seed: seed)
            var eligibleRNG = SeededRandomNumberGenerator(seed: seed)
            let withoutAltar = GameContent.pickMysteryEvent(
                context: ineligible,
                using: &ineligibleRNG,
            )
            let withAltarChance = GameContent.pickMysteryEvent(
                context: eligible,
                using: &eligibleRNG,
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
