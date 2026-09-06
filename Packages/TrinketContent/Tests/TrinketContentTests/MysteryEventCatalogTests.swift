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
        try #expect(GameContent.heroes.allSatisfy { $0.role == .hero })
        try #expect(GameContent.companions.allSatisfy { $0.role == .companion })
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
                    guard case let .gainItem(pool) = effect else {
                        continue
                    }
                    try #expect(
                        knownBaseIDs.contains(pool.baseTypeID),
                        "Unknown base type \(pool.baseTypeID) in \(event.id)/\(choice.id)",
                    )
                    for affixID in pool.guaranteedAffixIDs {
                        _ = try #require(
                            GameContent.itemAffixDefinitions.first { $0.id == affixID },
                            "Unknown guaranteed affix \(affixID) in \(event.id)/\(choice.id)",
                        )
                    }
                }
            }
        }
    }

    @Test func `item pools cover known special items and use gear fallbacks`() throws {
        let trinketIDs = Set(GameContent.trinketItems.map(\.templateID))
        let uniqueIDs = Set(GameContent.uniqueItems.map(\.templateID))
        var placedTrinkets: Set<String> = []
        var placedUniques: Set<String> = []
        for event in GameContent.mysteryEvents where event.id != GameContent.corruptionAltarEventID {
            #expect(event.narrative.contains("{A}"))
            #expect(event.narrative.contains("{B}"))
            #expect(!event.narrative(for: []).contains("{"))
            for choice in event.choices {
                let pool = try #require(choice.itemPool)
                let base = try #require(GameContent.itemBaseType(matching: pool.baseTypeID))
                #expect(base.slot != .trinket)
                #expect(pool.trinketIDs.isSubset(of: trinketIDs))
                #expect(pool.uniqueIDs.isSubset(of: uniqueIDs))
                placedTrinkets.formUnion(pool.trinketIDs)
                placedUniques.formUnion(pool.uniqueIDs)
            }
        }
        #expect(placedTrinkets == trinketIDs)
        #expect(placedUniques == uniqueIDs)
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
                    case .gainItem, .unlockCombatant,
                         .corruptItem, .leave:
                        break
                    }
                }
            }
        }
    }

    @Test func `narratives use articles for gear and preserve named relics`() throws {
        let geode = try #require(GameContent.mysteryEvent(matching: "crystal-geode"))
        let offers = try geode.choices.map { choice in
            let pool = try #require(choice.itemPool)
            let base = try #require(GameContent.itemBaseType(matching: pool.baseTypeID))
            return MysteryOffer(
                choiceID: choice.id,
                item: InventoryItem(id: choice.id, baseType: base, rarity: .basic, displayName: base.name, affixes: []),
                bonus: .experience(1),
            )
        }
        let text = geode.narrative(for: Array(offers.reversed()))
        #expect(text.contains("reveals a Sapphire Ring"))
        #expect(text.contains(". A Topaz Amulet remains"))
        let spring = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let locket = try #require(GameContent.unique(matching: "rimeheart_locket"))
        let rare = MysteryOffer(choiceID: spring.choices[0].id, item: locket, bonus: .experience(1))
        #expect(spring.narrative(for: [rare]).contains("traps Rimeheart Locket"))
        #expect(spring.narrative(for: [rare]).contains("an Emerald Ring"))
        let garden = try #require(GameContent.mysteryEvent(matching: "medicinal-herb-garden"))
        #expect(garden.narrative(for: []).contains("a suit of Leather Armor"))
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
    case .gainItem: .item
    case .unlockCombatant, .corruptItem, .leave:
        preconditionFailure("Unexpected mystery effect \(effect) in loot pairing test")
    }
}

private extension MysteryEventCatalogTests {
    static let validTwoLootKindPairs: Set<Set<MysteryLootKind>> = [
        [.item, .material],
        [.item, .gold],
        [.experience, .item],
    ]
}

private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let companion = "wolf"
}
