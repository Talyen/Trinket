import Foundation
import Testing
import TrinketContent
import TrinketCore

struct UniqueCatalogTests {
    @Test func `one unique per base type across slots`() {
        let baseIDs = GameContent.uniqueItems.map(\.baseType.id)
        #expect(Set(baseIDs).count == baseIDs.count)
        let equipmentBaseIDs = Set(GameContent.itemBaseTypes.filter { $0.slot != .trinket }.map(\.id))
        #expect(Set(baseIDs) == equipmentBaseIDs)
    }

    @Test func `unique affix keywords stay within base affinities`() {
        // Thematic Keyword Cohesion signatures use Bleed, Block, and Dodge for
        // hunting, patient defense, and evasive movement, even when the base
        // weapon affinities do not include Block or Dodge. Supports remain
        // within base affinities; only the bespoke signatures below are exempt.
        // Beastbond's affinity moves from Health to Physical per the plan, while
        // Wildheart's Favor keeps beastbond as a supporting power on an
        // Emerald Amulet (health,poison) base.
        let signatureExceptions: [String: Set<Keyword>] = [
            "the_patient_edge": [.block],
            "the_returning_gale": [.dodge],
        ]
        let supportExceptions: [String: Set<String>] = [
            "wildhearts_favor": ["beastbond"],
        ]
        for item in GameContent.uniqueItems {
            for affix in item.affixes {
                if affix.id == item.id, let allowed = signatureExceptions[item.id] {
                    #expect(
                        affix.keywords.isSubset(of: item.baseType.keywordAffinities.union(allowed)),
                        "\(item.id): \(affix.id) keywords outside \(item.baseType.id) affinities",
                    )
                    continue
                }
                if let allowedAffixes = supportExceptions[item.id], allowedAffixes.contains(affix.id) {
                    continue
                }
                #expect(
                    affix.keywords.isSubset(of: item.baseType.keywordAffinities),
                    "\(item.id): \(affix.id) keywords outside \(item.baseType.id) affinities",
                )
            }
        }
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

    @Test func `unique powers match every authored source at astral roll max`() throws {
        let randomPoolIDs = Set(GameContent.itemAffixDefinitions.map(\.id))
        for definition in GameContent.uniqueDefinitions {
            let item = try #require(GameContent.unique(matching: definition.id))
            #expect(item.rarity == .unique)
            #expect(item.displayName == definition.displayName)
            #expect(item.id == item.templateID)
            #expect(item.rewardInstance(for: "any-stage") == item)
            let powers = try #require(item.affixPowers)
            let sources = definition.affixes
            try #require(powers.count == sources.count && item.affixes.count == sources.count)
            for (index, source) in sources.enumerated() {
                #expect(!powers[index].description.isEmpty)
                switch source {
                case let .catalog(id):
                    let definition = try #require(GameContent.itemAffixDefinition(matching: id))
                    #expect(item.affixes[index].id == id)
                    #expect(powers[index] == definition.astral.rolledMax())
                case let .bespoke(bespoke):
                    #expect(!randomPoolIDs.contains(bespoke.id), Comment(rawValue: bespoke.id))
                    #expect(item.affixes[index].id == bespoke.id)
                    #expect(powers[index] == bespoke.astral.rolledMax())
                }
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
                rewardLevel: 1,
                allowedTiers: [.unique],
                ownedTrinketIDs: [],
                ownedUniqueIDs: allIDs.subtracting([item.id]),
                using: &rng,
            )
            #expect(reward == item)
        }
    }
}
