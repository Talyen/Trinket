import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func allMysteryEventsHaveUniqueIDs() throws {
        let ids = (GameContent.mysteryEvents + GameContent.recruitEvents).map(\.id)
        try #expect(ids.count == Set(ids).count)
        try #expect(GameContent.mysteryEvent(matching: "nonexistent-event") == nil)
        try #expect(GameContent.recruitEvent(matching: "nonexistent-event") == nil)
    }

    @Test func mysteryEventChoiceCountsMatchKind() throws {
        for event in GameContent.mysteryEvents {
            try #expect(
                event.choices.count == 2,
                "Mystery event \(event.id) should have exactly 2 choices"
            )
            try #expect(event.unlockCombatantID == nil)
        }
        for event in GameContent.recruitEvents {
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
        let unlockIDs = GameContent.recruitEvents.compactMap(\.unlockCombatantID)
        try #expect(unlockIDs.count == Set(unlockIDs).count)

        let expectedHeroes = Set(GameContent.heroes.map(\.id)).subtracting([PlayerRosterStarterIDs.hero])
        let expectedCompanions = Set(GameContent.companions.map(\.id)).subtracting([PlayerRosterStarterIDs.companion])
        try #expect(Set(unlockIDs.filter { expectedHeroes.contains($0) }) == expectedHeroes)
        try #expect(Set(unlockIDs.filter { expectedCompanions.contains($0) }) == expectedCompanions)
    }

    @Test func chapterRecruitCopyKeepsCombatantIdentityMysterious() throws {
        for stage in GameContent.chapters.flatMap(\.stages) {
            guard let eventID = stage.encounter.recruitEventID,
                  !eventID.isEmpty,
                  eventID != StageEncounter.randomCompanionRecruitID,
                  let event = RecruitEventPool.event(matching: eventID),
                  let combatant = GameContent.combatant(forMysteryEvent: event) else {
                continue
            }

            let copy = [event.title, event.narrative]
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
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
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
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
            guard let artID = event.artID else { continue }
            _ = try #require(
                ArtCatalog.encounterArtByID[artID],
                "Mystery event \(event.id) references unknown art ID \(artID)"
            )
        }
    }

    @Test func recruitResolutionUsesConfiguredThenDeterministicFallback() throws {
        let configured = try #require(GameContent.recruitEvent(matching: "recruit-bear"))
        let configuredPick = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion]
        )
        try #expect(configuredPick == .recruit(configured))

        let fallbackA = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"]
        )
        let fallbackB = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"]
        )
        try #expect(fallbackA == fallbackB)
        try #expect(fallbackA.event.isRecruit)
        try #expect(fallbackA.event.unlockCombatantID != "bear")
    }

    @Test func recruitResolutionUsesNonRecruitMysteryWhenRosterIsComplete() throws {
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: "recruit-bear",
            encounterID: "completed-roster-stage",
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id))
        )
        guard case let .mystery(event) = resolution else {
            Issue.record("Expected a Mystery replacement")
            return
        }
        try #expect(!event.isRecruit)
        try #expect(GameContent.mysteryEvents.contains(event))
    }

    @Test func generatedItemEffectsReferenceKnownBaseTypes() throws {
        let knownBaseIDs = Set(GameContent.itemBaseTypes.map(\.id))
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
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
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
            for choice in event.choices {
                for effect in choice.effects {
                    switch effect {
                    case let .gainGold(amount):
                        try #expect(amount > 0, "\(event.id)/\(choice.id)")
                    case .gainMaterial:
                        break
                    case .gainExperience:
                        break
                    case .gainGeneratedItem, .gainRandomItem, .unlockCombatant,
                         .corruptItem, .leave:
                        break
                    }
                }
            }
        }
    }

    @Test func recruitEncounterSymbolNameMatchesCombatantRole() throws {
        #expect(GameContent.recruitEncounterSymbolName(forEventID: nil) == "person.2.fill")
        #expect(GameContent.recruitEncounterSymbolName(for: .hero) == "person.2.fill")
        #expect(GameContent.recruitEncounterSymbolName(for: .companion) == "pawprint.fill")

        let heroEvent = try #require(GameContent.recruitEvent(matching: "recruit-ranger"))
        let hero = try #require(GameContent.combatant(forMysteryEvent: heroEvent))
        try #expect(hero.role == .hero)
        #expect(GameContent.recruitEncounterSymbolName(forEventID: "recruit-ranger") == "person.2.fill")
        #expect(StageEncounter.recruit(eventID: "recruit-ranger").symbolName == "person.2.fill")

        let companionEvent = try #require(GameContent.recruitEvent(matching: "recruit-bear"))
        let companion = try #require(GameContent.combatant(forMysteryEvent: companionEvent))
        try #expect(companion.role == .companion)
        #expect(GameContent.recruitEncounterSymbolName(forEventID: "recruit-bear") == "pawprint.fill")
        #expect(StageEncounter.recruit(eventID: "recruit-bear").symbolName == "pawprint.fill")

        #expect(LabyrinthNodeType.recruit.symbolName == "person.2.fill")
    }
}

/// Starter IDs mirrored from persistence without importing that package into content tests.
private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let companion = "wolf"
}
