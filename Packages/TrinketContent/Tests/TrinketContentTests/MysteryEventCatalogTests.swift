import TrinketCore
import Testing
@testable import TrinketContent

@Suite
struct MysteryEventCatalogTests {
    @Test func allMysteryEventsHaveUniqueIDs() throws {
        let ids = GameContent.mysteryEvents.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }

    @Test func allMysteryEventsHaveTwoChoices() throws {
        for event in GameContent.mysteryEvents {
            try #expect(
                event.choices.count == 2,
                "Mystery event \(event.id) should have exactly 2 choices"
            )
        }
    }

    @Test func allMysteryEventsHaveUniqueChoiceIDs() throws {
        for event in GameContent.mysteryEvents {
            let choiceIDs = event.choices.map(\.id)
            try #expect(
                choiceIDs.count == Set(choiceIDs).count,
                "Mystery event \(event.id) has duplicate choice IDs"
            )
        }
    }

    @Test func allMysteryEventsHaveAtLeastOneEffectPerChoice() throws {
        for event in GameContent.mysteryEvents {
            for choice in event.choices {
                try #expect(!choice.effects.isEmpty, "Choice \(choice.id)) in event \(event.id) has no effects")
            }
        }
    }

    @Test func artReferencesAreValid() throws {
        for event in GameContent.mysteryEvents {
            guard let artID = event.artID else { continue }
            _ = try #require(
                ArtCatalog.encounterArtByID[artID],
                "Mystery event \(event.id) references unknown art ID \(artID)"
            )
        }
    }

    @Test func mysteryEventLookup() throws {
        for event in GameContent.mysteryEvents {
            let lookedUp = try #require(GameContent.mysteryEvent(matching: event.id))
            try #expect(lookedUp.id == event.id)
        }
    }

    @Test func unknownMysteryEventReturnsNil() throws {
        try #expect(GameContent.mysteryEvent(matching: "nonexistent-event") == nil)
    }

    @Test func pickMysteryEventReturnsValidEvent() throws {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let picked = GameContent.pickMysteryEvent(using: &randomNumberGenerator)
        try #expect(GameContent.mysteryEvents.contains(picked))
    }
}
