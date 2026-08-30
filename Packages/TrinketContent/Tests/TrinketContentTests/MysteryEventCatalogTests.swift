import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func `unknown mystery and recruit I ds do not resolve`() throws {
        try #expect(GameContent.mysteryEvent(matching: "nonexistent-event") == nil)
        try #expect(GameContent.recruitEvent(matching: "nonexistent-event") == nil)
    }

    @Test func `mystery event choice counts match kind`() throws {
        for event in GameContent.mysteryEvents {
            try #expect(
                event.choices.count == 2,
                "Mystery event \(event.id) should have exactly 2 choices",
            )
            try #expect(event.unlockCombatantID == nil)
        }
        for event in GameContent.recruitEvents {
            try #expect(
                event.choices.count == 1,
                "Recruit event \(event.id) should have exactly 1 choice",
            )
            let combatantID = try #require(event.unlockCombatantID)
            try #expect(event.choices[0].effects == [.unlockCombatant(combatantID)])
        }
    }

    @Test func `recruit events cover every combatant exactly once`() throws {
        let unlockIDs = GameContent.recruitEvents.compactMap(\.unlockCombatantID)
        try #expect(unlockIDs.count == Set(unlockIDs).count)

        let expectedHeroes = Set(GameContent.heroes.map(\.id))
        let expectedCompanions = Set(GameContent.companions.map(\.id))
        try #expect(Set(unlockIDs.filter { expectedHeroes.contains($0) }) == expectedHeroes)
        try #expect(Set(unlockIDs.filter { expectedCompanions.contains($0) }) == expectedCompanions)
    }

    @Test func `starter options exist in their authored order and role`() throws {
        try #expect(GameContent.starterHeroes.map(\.id) == GameContent.starterHeroIDs)
        try #expect(GameContent.starterCompanions.map(\.id) == GameContent.starterCompanionIDs)
        try #expect(GameContent.starterHeroes.allSatisfy { $0.role == .hero })
        try #expect(GameContent.starterCompanions.allSatisfy { $0.role == .companion })
    }

    @Test func `all mystery event choices have unique I ds and at least one effect`() throws {
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
            let choiceIDs = event.choices.map(\.id)
            try #expect(
                choiceIDs.count == Set(choiceIDs).count,
                "Mystery event \(event.id) has duplicate choice IDs",
            )
            for choice in event.choices {
                try #expect(!choice.effects.isEmpty, "Choice \(choice.id) in event \(event.id) has no effects")
            }
        }
    }

    @Test func `art references are valid`() throws {
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
            guard let artID = event.artID else { continue }
            _ = try #require(
                ArtCatalog.encounterArtByID[artID],
                "Mystery event \(event.id) references unknown art ID \(artID)",
            )
        }
    }

    @Test func `recruit resolution uses configured then deterministic fallback`() throws {
        let configured = try #require(GameContent.recruitEvent(matching: "recruit-bear"))
        let configuredPick = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            worldSeed: 3,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion],
        )
        try #expect(configuredPick == .recruit(configured))

        let fallbackA = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            worldSeed: 3,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"],
        )
        let fallbackB = GameContent.resolveRecruitEncounter(
            configuredEventID: configured.id,
            encounterID: "campaign-stage",
            worldSeed: 3,
            unlockedHeroIDs: [PlayerRosterStarterIDs.hero],
            unlockedCompanionIDs: [PlayerRosterStarterIDs.companion, "bear"],
        )
        try #expect(fallbackA == fallbackB)
        try #expect(fallbackA.event.isRecruit)
        try #expect(fallbackA.event.unlockCombatantID != "bear")
    }

    @Test func `recruit resolution uses non recruit mystery when roster is complete`() throws {
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: "recruit-bear",
            encounterID: "completed-roster-stage",
            worldSeed: 3,
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
        )
        guard case let .mystery(event) = resolution else {
            Issue.record("Expected a Mystery replacement")
            return
        }
        try #expect(!event.isRecruit)
        try #expect(GameContent.mysteryEvents.contains(event))
    }

    @Test func `unchosen legacy starters remain eligible recruits`() throws {
        let knight = GameContent.resolveRecruitEncounter(
            configuredEventID: "recruit-knight",
            encounterID: "knight-recruit",
            worldSeed: 3,
            unlockedHeroIDs: ["rogue"],
            unlockedCompanionIDs: ["panther"],
        )
        let wolf = GameContent.resolveRecruitEncounter(
            configuredEventID: StageEncounter.randomCompanionRecruitID,
            encounterID: "wolf-recruit",
            worldSeed: 3,
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id)).subtracting(["wolf"]),
        )

        try #expect(knight.event.unlockCombatantID == "knight")
        try #expect(wolf.event.unlockCombatantID == "wolf")
    }

    @Test func `random battle enemy pick is stable per world and diverges across worlds`() throws {
        let stage = try #require(
            GameContent.chapters.flatMap(\.stages).first { $0.encounter == .randomBattle },
        )
        let first = try #require(stage.resolvedBattleEnemyID(worldSeed: 8))
        #expect(first == stage.resolvedBattleEnemyID(worldSeed: 8))
        let other = try #require(stage.resolvedBattleEnemyID(worldSeed: 9))
        #expect(first != other)
    }

    @Test func `ordinary mystery choices grant two loot effects`() throws {
        for event in GameContent.mysteryEvents where event.id != GameContent.corruptionAltarEventID {
            for choice in event.choices {
                try #expect(
                    choice.effects.count == 2,
                    "\(event.id)/\(choice.id) should grant exactly two effects",
                )
                let kinds = choice.effects.map(lootKind(for:))
                try #expect(
                    Self.validTwoLootKindPairs.contains(Set(kinds)),
                    "\(event.id)/\(choice.id) has invalid loot pairing \(kinds)",
                )
            }
        }
    }

    @Test func `generated item effects reference known base types`() throws {
        let knownBaseIDs = Set(GameContent.itemBaseTypes.map(\.id))
        for event in GameContent.mysteryEvents + GameContent.recruitEvents {
            for choice in event.choices {
                for effect in choice.effects {
                    guard case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs) = effect else {
                        continue
                    }
                    try #expect(
                        knownBaseIDs.contains(baseTypeID),
                        "Unknown base type \(baseTypeID) in \(event.id)/\(choice.id)",
                    )
                    for affixID in guaranteedAffixIDs {
                        _ = try #require(
                            GameContent.itemAffixDefinitions.first { $0.id == affixID },
                            "Unknown guaranteed affix \(affixID) in \(event.id)/\(choice.id)",
                        )
                    }
                }
            }
        }
    }

    @Test func `themed trinket ties resolve known choices and trinkets`() throws {
        let knownTrinketIDs = Set(GameContent.trinketItems.map(\.id))
        let choiceIDs = Set(GameContent.mysteryEvents.flatMap { $0.choices.map(\.id) })

        try #expect(!GameContent.themedTrinketsByMysteryChoiceID.isEmpty)
        for (choiceID, trinketIDs) in GameContent.themedTrinketsByMysteryChoiceID {
            try #expect(choiceIDs.contains(choiceID), "Mapped choice \(choiceID) is missing from the pool")
            try #expect(!trinketIDs.isEmpty, "Mapped choice \(choiceID) awards no trinkets")
            for trinketID in trinketIDs {
                try #expect(
                    knownTrinketIDs.contains(trinketID),
                    "Mapped trinket \(trinketID) for \(choiceID) is unknown",
                )
            }
            try #expect(GameContent.themedTrinketIDs(forMysteryChoiceID: choiceID) == trinketIDs)
        }
        try #expect(GameContent.themedTrinketIDs(forMysteryChoiceID: "harvest-berries") == nil)
    }

    @Test func `mystery effects never spend resources`() throws {
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

    @Test func `recruit events resolve combatant roles`() throws {
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

private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let companion = "wolf"
}
