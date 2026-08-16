import Testing
import TrinketCore
@testable import TrinketContent

struct CombatantTalentCatalogTests {
    @Test func allHeroesHaveThreeKeywordsAndSixNodesPerTree() {
        for hero in GameContent.heroes {
            let config = CombatantTalentCatalog.config(for: hero.id)
            #expect(config.combatantID == hero.id)
            #expect(config.trees.count == 3)
            for tree in config.trees {
                #expect(tree.nodes.count == 6)
                #expect(tree.nodes(forTier: 1).count == 2)
                #expect(tree.nodes(forTier: 2).count == 2)
                #expect(tree.nodes(forTier: 3).count == 2)
            }
        }
    }

    @Test func allCompanionsHaveThreeKeywordsAndSixNodesPerTree() {
        for companion in GameContent.companions {
            let config = CombatantTalentCatalog.config(for: companion.id)
            #expect(config.combatantID == companion.id)
            #expect(config.trees.count == 3)
            for tree in config.trees {
                #expect(tree.nodes.count == 6)
                #expect(tree.nodes(forTier: 1).count == 2)
                #expect(tree.nodes(forTier: 2).count == 2)
                #expect(tree.nodes(forTier: 3).count == 2)
            }
        }
    }

    @Test func expectedHeroKeywordAffinitiesMatch() {
        let knight = CombatantTalentCatalog.config(for: "knight")
        #expect(knight.trees.map(\.keyword) == [.block, .holy, .stun])

        let rogue = CombatantTalentCatalog.config(for: "rogue")
        #expect(rogue.trees.map(\.keyword) == [.poison, .bleed, .dodge])

        let wizard = CombatantTalentCatalog.config(for: "wizard")
        #expect(wizard.trees.map(\.keyword) == [.freeze, .burn, .mana])

        let warlock = CombatantTalentCatalog.config(for: "warlock")
        #expect(warlock.trees.map(\.keyword) == [.burn, .leech, .mana])

        let pixie = CombatantTalentCatalog.config(for: "pixie")
        #expect(pixie.trees.map(\.keyword) == [.cleanse, .health, .holy])

        let owl = CombatantTalentCatalog.config(for: "library_owl")
        #expect(owl.trees.map(\.keyword) == [.holy, .cleanse, .health])
    }
}
