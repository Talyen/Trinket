import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func allMysteryEventsHaveUniqueIDs() throws {
        let ids = GameContent.mysteryEvents.map(\.id)
        try #expect(ids.count == Set(ids).count)
        try #expect(GameContent.mysteryEvent(matching: "nonexistent-event") == nil)
    }

    @Test func mysteryEventChoiceCountsMatchKind() throws {
        for event in GameContent.branchingMysteryEvents {
            try #expect(
                event.choices.count == 2,
                "Mystery event \(event.id) should have exactly 2 choices"
            )
            try #expect(event.unlockCombatantID == nil)
        }
        for event in GameContent.recruitMysteryEvents {
            try #expect(
                event.choices.count == 1,
                "Recruit event \(event.id) should have exactly 1 choice"
            )
            let combatantID = try #require(event.unlockCombatantID)
            try #expect(event.choices[0].effects == [.unlockCombatant(combatantID)])
            try #expect(
                combatantID != PlayerRosterStarterIDs.hero
                    && combatantID != PlayerRosterStarterIDs.companion,
                "Recruit event \(event.id) should not unlock starters"
            )
        }
    }

    @Test func recruitEventsCoverEveryNonStarterCombatantExactlyOnce() throws {
        let unlockIDs = GameContent.recruitMysteryEvents.compactMap(\.unlockCombatantID)
        try #expect(unlockIDs.count == Set(unlockIDs).count)

        let expectedHeroes = Set(GameContent.heroes.map(\.id)).subtracting([PlayerRosterStarterIDs.hero])
        let expectedCompanions = Set(GameContent.companions.map(\.id)).subtracting([PlayerRosterStarterIDs.companion])
        try #expect(Set(unlockIDs.filter { expectedHeroes.contains($0) }) == expectedHeroes)
        try #expect(Set(unlockIDs.filter { expectedCompanions.contains($0) }) == expectedCompanions)
    }

    @Test func chapterRecruitCopyKeepsCombatantIdentityMysterious() throws {
        for stage in GameContent.chapters.flatMap(\.stages) {
            guard let eventID = stage.encounter.mysteryEventID,
                  let event = RecruitMysteryEventPool.event(matching: eventID),
                  let combatant = GameContent.combatant(forMysteryEvent: event) else {
                continue
            }

            let copy = [stage.flavorText, event.title, event.narrative]
                .joined(separator: " ")
                .lowercased()
            let identityWords = combatant.name
                .lowercased()
                .split(separator: " ")
                .filter { $0.count > 3 }

            for identityWord in identityWords {
                try #expect(
                    !copy.contains(identityWord),
                    "Chapter recruit event \(event.id) gives away \(combatant.name)"
                )
            }
        }
    }

    @Test func allMysteryEventChoicesHaveUniqueIDsAndAtLeastOneEffect() throws {
        for event in GameContent.mysteryEvents {
            let choiceIDs = event.choices.map(\.id)
            try #expect(
                choiceIDs.count == Set(choiceIDs).count,
                "Mystery event \(event.id) has duplicate choice IDs"
            )
            for choice in event.choices {
                try #expect(!choice.effects.isEmpty, "Choice \(choice.id) in event \(event.id) has no effects")
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

    @Test func pickEligibleMysteryEventRespectsRosterUnlocks() throws {
        var lockedRNG = SeededRandomNumberGenerator(seed: 7)
        let lockedPick = GameContent.pickEligibleMysteryEvent(
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion],
            using: &lockedRNG
        )
        try #expect(lockedPick.isRecruit)
        try #expect(lockedPick.unlockCombatantID != PlayerRosterStarterIDs.hero)
        try #expect(lockedPick.unlockCombatantID != PlayerRosterStarterIDs.companion)

        var unlockedRNG = SeededRandomNumberGenerator(seed: 3)
        let unlockedPick = GameContent.pickEligibleMysteryEvent(
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
            using: &unlockedRNG
        )
        try #expect(!unlockedPick.isRecruit)
        try #expect(GameContent.branchingMysteryEvents.contains(unlockedPick))
    }

    @Test func resolveMysteryEncounterEventKeepsAuthoredRecruitAuthoritative() throws {
        let recruit = try #require(RecruitMysteryEventPool.event(matching: "recruit-bear"))
        var rng = SeededRandomNumberGenerator(seed: 11)

        let present = GameContent.resolveMysteryEncounterEvent(
            authored: recruit,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion],
            using: &rng
        )
        try #expect(present == recruit)

        let unavailable = GameContent.resolveMysteryEncounterEvent(
            authored: recruit,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"],
            using: &rng
        )
        try #expect(unavailable == nil)
    }

    @Test func resolveMysteryEncounterEventPicksEligibleWhenUnauthored() throws {
        var lockedRNG = SeededRandomNumberGenerator(seed: 19)
        let lockedPick = try #require(
            GameContent.resolveMysteryEncounterEvent(
                authored: nil,
                unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
                unlockedCompanionIDs: [PlayerRosterStarterIDs.companion],
                using: &lockedRNG
            )
        )
        try #expect(lockedPick.isRecruit)

        var unlockedRNG = SeededRandomNumberGenerator(seed: 23)
        let unlockedPick = try #require(
            GameContent.resolveMysteryEncounterEvent(
                authored: nil,
                unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
                unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
                using: &unlockedRNG
            )
        )
        try #expect(!unlockedPick.isRecruit)
        try #expect(GameContent.branchingMysteryEvents.contains(unlockedPick))
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
    static let companion = "wolf"
}
