import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func allMysteryEventsHaveUniqueIDs() throws {
        let ids = GameContent.mysteryEvents.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }

    @Test func branchingMysteryEventsHaveTwoChoices() throws {
        for event in GameContent.branchingMysteryEvents {
            try #expect(
                event.choices.count == 2,
                "Mystery event \(event.id) should have exactly 2 choices"
            )
            try #expect(event.unlockCombatantID == nil)
        }
    }

    @Test func recruitMysteryEventsHaveOneUnlockChoice() throws {
        for event in GameContent.recruitMysteryEvents {
            try #expect(
                event.choices.count == 1,
                "Recruit event \(event.id) should have exactly 1 choice"
            )
            let combatantID = try #require(event.unlockCombatantID)
            try #expect(event.choices[0].effects == [.unlockCombatant(combatantID)])
            try #expect(
                combatantID != PlayerRosterStarterIDs.hero
                    && combatantID != PlayerRosterStarterIDs.pet,
                "Recruit event \(event.id) should not unlock starters"
            )
        }
    }

    @Test func recruitEventsCoverEveryNonStarterCombatantExactlyOnce() throws {
        let unlockIDs = GameContent.recruitMysteryEvents.compactMap(\.unlockCombatantID)
        try #expect(unlockIDs.count == Set(unlockIDs).count)

        let expectedHeroes = Set(GameContent.heroes.map(\.id)).subtracting([PlayerRosterStarterIDs.hero])
        let expectedPets = Set(GameContent.pets.map(\.id)).subtracting([PlayerRosterStarterIDs.pet])
        try #expect(Set(unlockIDs.filter { expectedHeroes.contains($0) }) == expectedHeroes)
        try #expect(Set(unlockIDs.filter { expectedPets.contains($0) }) == expectedPets)
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

    @Test func recruitEventsResolveCombatantArt() throws {
        for event in GameContent.recruitMysteryEvents {
            let combatant = try #require(GameContent.combatant(forMysteryEvent: event))
            _ = try #require(
                combatant.artReference,
                "Recruit event \(event.id) combatant \(combatant.id) missing art"
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

    @Test func pickMysteryEventReturnsValidBranchingEvent() throws {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let picked = GameContent.pickMysteryEvent(using: &randomNumberGenerator)
        try #expect(GameContent.branchingMysteryEvents.contains(picked))
    }

    @Test func pickEligibleMysteryEventPrefersLockedRecruits() throws {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let picked = GameContent.pickEligibleMysteryEvent(
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedPetIDs: [PlayerRosterStarterIDs.pet],
            using: &randomNumberGenerator
        )
        try #expect(picked.isRecruit)
        try #expect(picked.unlockCombatantID != PlayerRosterStarterIDs.hero)
        try #expect(picked.unlockCombatantID != PlayerRosterStarterIDs.pet)
    }

    @Test func pickEligibleMysteryEventFallsBackWhenAllUnlocked() throws {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let picked = GameContent.pickEligibleMysteryEvent(
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedPetIDs: Set(GameContent.pets.map(\.id)),
            using: &randomNumberGenerator
        )
        try #expect(!picked.isRecruit)
        try #expect(GameContent.branchingMysteryEvents.contains(picked))
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
                    case .gainGeneratedItem, .gainRandomItem, .chooseItem, .unlockCombatant:
                        break
                    }
                }
            }
        }
    }
}

/// Starter IDs mirrored from persistence without importing that package into content tests.
private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let pet = "bear"
}
