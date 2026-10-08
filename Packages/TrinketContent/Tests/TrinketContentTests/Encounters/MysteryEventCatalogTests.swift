import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import TrinketContent

struct MysteryEventCatalogTests {
    @Test func `recruit events cover every combatant exactly once`() throws {
        let unlockIDs = GameContent.recruitEvents.compactMap(\.unlockCombatantID)
        try #expect(unlockIDs.count == Set(unlockIDs).count)

        let expectedHeroes = Set(GameContent.heroes.map(\.id))
        let expectedCompanions = Set(GameContent.companions.map(\.id))
        #expect(Set(unlockIDs) == expectedHeroes.union(expectedCompanions))
        for event in GameContent.recruitEvents {
            let combatant = try #require(GameContent.combatant(forMysteryEvent: event), "Unresolvable recruit \(event.id)")
            #expect(event.choices.map(\.effects) == [[.unlockCombatant(combatant.id)]])
        }
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

    @Test func `free roster exhaustion also falls back to non recruit mystery`() throws {
        let resolution = GameContent.resolveRecruitEncounter(
            configuredEventID: "recruit-bear",
            encounterID: "completed-free-roster-stage",
            worldSeed: 3,
            unlockedHeroIDs: Set(ContentAccessPolicy.freeHeroIDs),
            unlockedCompanionIDs: Set(ContentAccessPolicy.freeCompanionIDs),
            access: .free,
        )
        guard case let .mystery(event) = resolution else {
            Issue.record("Expected a Mystery replacement")
            return
        }
        try #expect(!event.isRecruit)
        try #expect(GameContent.mysteryEvents.contains(event))
    }

    @Test func `Forest recruits Knight after Ranger and replaces an already chosen Knight`() throws {
        let stage = try #require(GameContent.chapters.flatMap(\.stages).first {
            $0.chapterNumber == 1 && $0.stageNumber == 5
        })
        #expect(stage.encounter.recruitEventID == "recruit-knight")
        for starterID in ["ranger", "knight"] {
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: stage.encounter.recruitEventID,
                encounterID: stage.id,
                worldSeed: 3,
                unlockedHeroIDs: [starterID],
                unlockedCompanionIDs: ["wolf"],
                access: .free,
            )
            let recruitedID = try #require(resolution.event.unlockCombatantID)
            #expect(recruitedID != starterID && recruitedID != "wolf")
            #expect(ContentAccessPolicy.isFreeCombatant(recruitedID))
            if starterID == "ranger" {
                #expect(recruitedID == "knight")
            }
        }
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
        let picks = try (UInt64(8) ... 23).map { try #require(stage.resolvedBattleEnemyID(worldSeed: $0)) }
        #expect(Set(picks).count > 1)
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
                try #require(choice.effects.count == 2, "\(event.id)/\(choice.id)")
                #expect(choice.effects.count(where: { effect in
                    switch effect {
                    case .gainGold, .gainMaterial, .gainExperience: true
                    default: false
                    }
                }) == 1, "\(event.id)/\(choice.id) needs one bonus")
                let pool = try #require(choice.itemPool)
                for affixID in pool.guaranteedAffixIDs {
                    _ = try #require(GameContent.itemAffixDefinition(matching: affixID), "Unknown guaranteed affix \(affixID)")
                }
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
}

private enum PlayerRosterStarterIDs {
    static let hero = "knight"
    static let companion = "wolf"
}
