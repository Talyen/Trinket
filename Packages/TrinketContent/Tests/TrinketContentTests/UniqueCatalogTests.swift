import Foundation
import Testing
import TrinketContent
import TrinketCore

struct UniqueCatalogTests {
    @Test func `uniques resolve for every definition`() throws {
        try #expect(GameContent.uniqueItems.count == GameContent.uniqueDefinitions.count)
        for definition in GameContent.uniqueDefinitions {
            let item = try #require(GameContent.unique(matching: definition.id))
            #expect(item.rarity == .unique)
            #expect(item.displayName == definition.displayName)
        }
    }

    @Test func `one unique per base type across slots`() {
        let baseIDs = GameContent.uniqueItems.map(\.baseType.id)
        #expect(Set(baseIDs).count == baseIDs.count)
        let equipmentBaseIDs = Set(GameContent.itemBaseTypes.filter { $0.slot != .trinket }.map(\.id))
        #expect(Set(baseIDs) == equipmentBaseIDs)

        let slots = Set(GameContent.uniqueItems.map(\.baseType.slot.baseItemSlot))
        #expect(slots == [.weapon, .armor, .accessory])
    }

    @Test func `unique affix keywords stay within base affinities`() {
        for item in GameContent.uniqueItems {
            for affix in item.affixes {
                #expect(
                    affix.keywords.isSubset(of: item.baseType.keywordAffinities),
                    "\(item.id): \(affix.id) keywords outside \(item.baseType.id) affinities",
                )
            }
        }
    }

    @Test func `uniques pin exact powers and stable identity`() throws {
        for item in GameContent.uniqueItems {
            let powers = try #require(item.affixPowers)
            #expect(powers.count == item.affixes.count)
            #expect(item.id == item.templateID)
            #expect(item.rewardInstance(for: "any-stage") == item)
            for power in powers {
                #expect(!power.description.isEmpty)
            }
        }
    }

    @Test func `catalog supports reference existing definitions`() {
        for definition in GameContent.uniqueDefinitions {
            for source in definition.affixes {
                if case let .catalog(id) = source {
                    #expect(GameContent.itemAffixDefinition(matching: id) != nil, Comment(rawValue: id))
                }
            }
        }
    }

    @Test func `bespoke signatures never enter the random pool`() {
        let poolIDs = Set(GameContent.itemAffixDefinitions.map(\.id))
        for definition in GameContent.uniqueDefinitions {
            for source in definition.affixes {
                if case let .bespoke(bespoke) = source {
                    #expect(!poolIDs.contains(bespoke.id), Comment(rawValue: bespoke.id))
                }
            }
        }
    }

    @Test func `every signature has supporting astral max affixes`() throws {
        for item in GameContent.uniqueItems {
            try #expect(item.affixes.count == 4, Comment(rawValue: item.id))
            #expect(item.affixPowers?.count == item.affixes.count)
        }
    }

    @Test func `new unique packages resolve exactly`() throws {
        let expected: [String: (base: String, affixes: [String])] = [
            "blackfletch": ("crossbow", ["blackfletch", "infected", "lingering", "contagion"]),
            "twin_casting": ("staff", ["twin_casting", "smoldering", "glacial", "channeled"]),
            "saintfall_plate": ("plate_armor", ["saintfall", "bulwark", "sanctum", "vital"]),
            "golden_verdict": ("topaz_ring", ["golden_verdict", "stunning", "lucky", "absolving"]),
        ]

        for (id, package) in expected {
            let item = try #require(GameContent.unique(matching: id))
            #expect(item.baseType.id == package.base)
            #expect(item.affixes.map(\.id) == package.affixes)
        }
    }

    @Test func `staff and channeled use mana only elemental affinity`() throws {
        let staff = try #require(GameContent.itemBaseType(matching: "staff"))
        #expect(staff.keywordAffinities == [.burn, .freeze, .mana])

        let channeled = try #require(GameContent.itemAffixDefinition(matching: "channeled"))
        #expect(channeled.slot == .weapon)
        #expect(channeled.keywords == [.mana])
        #expect(channeled.basic.modifiers == [.maximumMana(4)])
        #expect(channeled.astral.modifiers == [.maximumMana(8)])
    }

    @Test func `basic astral unique and trinket catalogs do not overlap`() {
        #expect(GameContent.uniqueItems.allSatisfy { !$0.isTrinket && $0.rarity == .unique })
        #expect(GameContent.sampleInventoryItems.allSatisfy { !$0.isTrinket && $0.rarity != .unique })
        #expect(GameContent.trinketItems.allSatisfy { $0.isTrinket && $0.rarity != .unique })

        let uniqueIDs = Set(GameContent.uniqueItems.map(\.id))
        let trinketIDs = Set(GameContent.trinketItems.map(\.id))
        let sampleIDs = Set(GameContent.sampleInventoryItems.map(\.id))
        #expect(uniqueIDs.isDisjoint(with: trinketIDs))
        #expect(sampleIDs.isDisjoint(with: trinketIDs))
        #expect(sampleIDs.isDisjoint(with: uniqueIDs))
    }

    @Test func `unique items use base item artwork`() throws {
        for item in GameContent.uniqueItems {
            let art = try #require(item.artReference, "Unique item \(item.id) should have an art reference")
            #expect(
                art == item.baseType.previewArtReference,
                "Unique item \(item.id) art (\(art.imageName)) must match base type \(item.baseType.id) art",
            )
        }
    }

    @Test func `completed collection pins standard supporting powers`() throws {
        let expected: [String: [String]] = [
            "the_unclosing_wound": ["keen", "serrated", "leeching"],
            "kingbreaker": ["keen", "concussive", "defenders"],
            "everkeen": ["keen", "serrated", "dazed"],
            "red_harvest": ["keen", "serrated", "leeching"],
            "oathkeeper": ["keen", "consecrated", "serrated"],
            "the_patient_edge": ["keen", "serrated", "envenomed"],
            "vipers_courtesy": ["envenomed", "serrated", "leeching"],
            "the_lingering_bell": ["concussive", "consecrated", "dazed"],
            "huntsmasters_call": ["keen", "serrated", "envenomed"],
            "wrenflight": ["keen", "infected", "contagion"],
            "the_returning_gale": ["keen", "serrated", "lingering"],
            "the_final_spark": ["smoldering", "glacial", "channeled"],
            "laughing_guard": ["elusive", "untouchable", "defenders"],
            "the_knights_answer": ["concussive", "dazed", "defenders"],
            "the_returning_flight": ["keen", "envenomed", "infected"],
            "threefold_grace": ["smoldering", "glacial", "consecrated"],
            "bloodember_pendant": ["smoldering", "serrated", "vampiric"],
            "winters_credit": ["rime", "aetherward", "manabound"],
            "serpents_eye": ["envenomed", "contagion", "hale"],
            "wildhearts_favor": ["envenomed", "hale", "beastbond"],
            "the_golden_crucible": ["lucky", "gilded", "absolving"],
        ]
        for (id, supports) in expected {
            let item = try #require(GameContent.unique(matching: id))
            let powers = try #require(item.affixPowers)
            #expect(item.affixes.first?.id == id)
            for (index, support) in supports.enumerated() {
                let definition = try #require(GameContent.itemAffixDefinition(matching: support))
                #expect(powers[index + 1] == definition.astral)
                #expect(item.affixes[index + 1].title == definition.title)
            }
        }
    }

    @Test func `new unique powers decode with old payload defaults`() throws {
        let old = try ItemAffixPowerCoding.decode(Data("[{\"description\":\"Old\",\"modifiers\":[],\"triggers\":{}}]".utf8))
        #expect(old.first?.triggers == CombatTraitTriggers())
        for item in GameContent.uniqueItems {
            let powers = try #require(item.affixPowers)
            let restored = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode(powers))
            #expect(restored == powers)
        }
    }

    @Test func `every unowned unique is available through normal rewards`() {
        let allIDs = Set(GameContent.uniqueItems.map(\.id))
        for item in GameContent.uniqueItems {
            var rng = SeededRandomNumberGenerator(seed: 1772)
            let reward = ItemRewardGenerator.generate(
                id: "reward",
                tier: .unique,
                ownedTrinketIDs: [],
                ownedUniqueIDs: allIDs.subtracting([item.id]),
                using: &rng,
            )
            #expect(reward == item)
        }
    }
}
