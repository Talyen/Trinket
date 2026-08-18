import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func unknownMysteryAndRecruitIDsDoNotResolve() throws {
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
            worldSeed: 3,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion]
        )
        try #expect(configuredPick == .recruit(configured))

        let fallbackA = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            worldSeed: 3,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"]
        )
        let fallbackB = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            worldSeed: 3,
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
            worldSeed: 3,
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

    @Test func randomBattleEnemyPickIsStablePerWorldAndDivergesAcrossWorlds() throws {
        let stage = try #require(
            GameContent.chapters.flatMap(\.stages).first { $0.encounter == .randomBattle }
        )
        let first = try #require(stage.resolvedBattleEnemyID(worldSeed: 8))
        #expect(first == stage.resolvedBattleEnemyID(worldSeed: 8))
        let other = try #require(stage.resolvedBattleEnemyID(worldSeed: 9))
        #expect(first != other)
    }

    @Test func ordinaryMysteryChoicesGrantTwoLootEffects() throws {
        for event in GameContent.mysteryEvents where event.id != GameContent.corruptionAltarEventID {
            for choice in event.choices {
                try #expect(
                    choice.effects.count == 2,
                    "\(event.id)/\(choice.id) should grant exactly two effects"
                )
                let kinds = choice.effects.map(lootKind(for:))
                try #expect(
                    Self.validTwoLootKindPairs.contains(Set(kinds)),
                    "\(event.id)/\(choice.id) has invalid loot pairing \(kinds)"
                )
            }
        }
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

    @Test func onlyStrongMysteryChoiceTiesCanAwardTrinkets() throws {
        let expected: [String: Set<String>] = [
            "take-the-charm": ["icy_heart"],
            "take-the-gold": ["lucky_clover"],
            "pick-mushrooms": ["parasitic_bloom"],
            "claim-blade": ["cutpurse_knife"],
            "search-the-crypt": ["bone_charm", "sin_eaters_lantern"],
            "take-the-quill": ["runic_quill"],
            "take-the-pages": ["tattered_pages"],
            "take-a-fragment": ["meteorite"],
            "collect-the-bones": ["bone_charm"],
            "mine-the-cliffside": ["thunderstone"],
            "take-the-salts": ["bone_charm"],
            "harvest-remedies": ["mortar_and_pestle"],
            "take-the-notes": ["tattered_pages"],
            "take-the-chimes": ["resonant_chimes"],
            "claim-censer": ["brass_censer"],
        ]

        let choiceIDs = Set(GameContent.mysteryEvents.flatMap { $0.choices.map(\.id) })
        for (choiceID, trinketIDs) in expected {
            try #expect(choiceIDs.contains(choiceID), "Mapped choice \(choiceID) is missing from the pool")
            try #expect(GameContent.themedTrinketIDs(forMysteryChoiceID: choiceID) == trinketIDs)
        }
        try #expect(GameContent.themedTrinketIDs(forMysteryChoiceID: "harvest-berries") == nil)
        try #expect(GameContent.themedTrinketIDs(forMysteryChoiceID: "forgotten-hoard") == nil)
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

    @Test func recruitEventsResolveCombatantRoles() throws {
        let heroEvent = try #require(GameContent.recruitEvent(matching: "recruit-ranger"))
        let hero = try #require(GameContent.combatant(forMysteryEvent: heroEvent))
        try #expect(hero.role == .hero)

        let companionEvent = try #require(GameContent.recruitEvent(matching: "recruit-bear"))
        let companion = try #require(GameContent.combatant(forMysteryEvent: companionEvent))
        try #expect(companion.role == .companion)
    }
}

private enum MysteryLootKind: Hashable {
    case experience
    case gold
    case material
    case item
}

private func lootKind(for effect: MysteryEffect) -> MysteryLootKind {
    switch effect {
    case .gainExperience: .experience
    case .gainGold: .gold
    case .gainMaterial: .material
    case .gainGeneratedItem, .gainRandomItem: .item
    case .unlockCombatant, .corruptItem, .leave:
        preconditionFailure("Unexpected mystery effect \(effect) in loot pairing test")
    }
}

private extension MysteryEventCatalogTests {
    static let validTwoLootKindPairs: Set<Set<MysteryLootKind>> = [
        [.item, .material],
        [.item, .gold],
        [.experience, .material],
        [.experience, .gold],
        [.experience, .item],
        [.gold, .material],
    ]
}

/// Starter IDs mirrored from persistence without importing that package into content tests.
private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let companion = "wolf"
}
