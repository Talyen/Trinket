import Testing
import TrinketCore
@testable import TrinketContent

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

    @Test func generatedItemEffectsReferenceKnownBaseTypes() throws {
        let knownBaseIDs = Set(GameContent.itemBaseTypes.map(\.id))
        for event in GameContent.mysteryEvents {
            for choice in event.choices {
                for effect in choice.effects {
                    guard case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs) = effect else {
                        continue
                    }
                    try #expect(
                        knownBaseIDs.contains(baseTypeID),
                        "Unknown base type \(baseTypeID) in \(event.id)/\(choice.id)"
                    )
                    for affixID in guaranteedAffixIDs {
                        _ = try #require(
                            GameContent.itemAffixDefinitions.first { $0.id == affixID },
                            "Unknown guaranteed affix \(affixID) in \(event.id)/\(choice.id)"
                        )
                    }
                }
            }
        }
    }

    @Test func manaBerryHarvestGrantsHerbsAndManaboundSapphireRing() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let harvest = try #require(event.choices.first { $0.id == "harvest" })
        try #expect(harvest.effects.contains(.gainMaterial(.herbs, 3)))
        try #expect(
            harvest.effects.contains(
                .gainGeneratedItem(baseTypeID: "sapphire_ring", guaranteedAffixIDs: ["manabound"])
            )
        )
    }

    @Test func mysteryEffectsNeverSpendResources() throws {
        for event in GameContent.mysteryEvents {
            for choice in event.choices {
                for effect in choice.effects {
                    switch effect {
                    case let .gainGold(amount):
                        try #expect(amount > 0, "\(event.id)/\(choice.id)")
                    case let .gainMaterial(_, amount):
                        try #expect(amount > 0, "\(event.id)/\(choice.id)")
                    case let .gainExperience(amount):
                        try #expect(amount > 0, "\(event.id)/\(choice.id)")
                    case .gainGeneratedItem, .gainRandomItem, .chooseItem:
                        break
                    }
                }
            }
        }
    }
}
