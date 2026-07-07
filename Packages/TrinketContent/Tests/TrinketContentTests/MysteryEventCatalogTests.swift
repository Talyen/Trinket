import TrinketCore
import XCTest
@testable import TrinketContent

final class MysteryEventCatalogTests: XCTestCase {
    func testAllMysteryEventsHaveUniqueIDs() {
        let ids = GameContent.mysteryEvents.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testAllMysteryEventsHaveTwoChoices() {
        for event in GameContent.mysteryEvents {
            XCTAssertEqual(
                event.choices.count, 2,
                "Mystery event \(event.id) should have exactly 2 choices"
            )
        }
    }

    func testAllMysteryEventsHaveUniqueChoiceIDs() {
        for event in GameContent.mysteryEvents {
            let choiceIDs = event.choices.map(\.id)
            XCTAssertEqual(
                choiceIDs.count, Set(choiceIDs).count,
                "Mystery event \(event.id) has duplicate choice IDs"
            )
        }
    }

    func testAllMysteryEventsHaveAtLeastOneEffectPerChoice() {
        for event in GameContent.mysteryEvents {
            for choice in event.choices {
                XCTAssertFalse(
                    choice.effects.isEmpty,
                    "Choice \(choice.id) in event \(event.id) has no effects"
                )
            }
        }
    }

    func testArtReferencesAreValid() throws {
        for event in GameContent.mysteryEvents {
            guard let artID = event.artID else { continue }
            _ = try XCTUnwrap(
                ArtCatalog.encounterArtByID[artID],
                "Mystery event \(event.id) references unknown art ID \(artID)"
            )
        }
    }

    func testMysteryEventLookup() throws {
        for event in GameContent.mysteryEvents {
            let lookedUp = try XCTUnwrap(GameContent.mysteryEvent(matching: event.id))
            XCTAssertEqual(lookedUp.id, event.id)
        }
    }

    func testUnknownMysteryEventReturnsNil() {
        XCTAssertNil(GameContent.mysteryEvent(matching: "nonexistent-event"))
    }

    func testPickMysteryEventReturnsValidEvent() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let picked = GameContent.pickMysteryEvent(using: &randomNumberGenerator)
        XCTAssertTrue(GameContent.mysteryEvents.contains(picked))
    }
}
