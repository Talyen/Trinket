import Testing
import TrinketContent
import TrinketCore

struct UniqueCatalogTests {
    @Test func uniquesResolveForEveryDefinition() throws {
        try #expect(GameContent.uniqueItems.count == GameContent.uniqueDefinitions.count)
        for definition in GameContent.uniqueDefinitions {
            let item = try #require(GameContent.unique(matching: definition.id))
            #expect(item.rarity == .unique)
            #expect(item.displayName == definition.displayName)
        }
    }

    @Test func oneUniquePerBaseTypeAcrossSlots() {
        let baseIDs = GameContent.uniqueItems.map(\.baseType.id)
        #expect(Set(baseIDs).count == baseIDs.count)

        let slots = Set(GameContent.uniqueItems.map(\.baseType.slot.baseItemSlot))
        #expect(slots == [.weapon, .armor, .accessory])
    }

    @Test func uniqueAffixKeywordsStayWithinBaseAffinities() {
        for item in GameContent.uniqueItems {
            for affix in item.affixes {
                #expect(
                    affix.keywords.isSubset(of: item.baseType.keywordAffinities),
                    "\(item.id): \(affix.id) keywords outside \(item.baseType.id) affinities"
                )
            }
        }
    }

    @Test func uniquesPinExactPowersAndStableIdentity() throws {
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

    @Test func catalogSupportsReferenceExistingDefinitions() {
        for definition in GameContent.uniqueDefinitions {
            for source in definition.affixes {
                if case let .catalog(id) = source {
                    #expect(GameContent.itemAffixDefinition(matching: id) != nil, Comment(rawValue: id))
                }
            }
        }
    }

    @Test func bespokeSignaturesNeverEnterTheRandomPool() {
        let poolIDs = Set(GameContent.itemAffixDefinitions.map(\.id))
        for definition in GameContent.uniqueDefinitions {
            for source in definition.affixes {
                if case let .bespoke(bespoke) = source {
                    #expect(!poolIDs.contains(bespoke.id), Comment(rawValue: bespoke.id))
                }
            }
        }
    }

    @Test func everySignatureHasSupportingAstralMaxAffixes() throws {
        for item in GameContent.uniqueItems {
            try #expect(item.affixes.count >= 4, Comment(rawValue: item.id))
            #expect(item.affixPowers?.count == item.affixes.count)
        }
    }
}
