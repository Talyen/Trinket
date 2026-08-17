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
                #expect(!tree.name.isEmpty)
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
                #expect(!tree.name.isEmpty)
                #expect(tree.nodes.count == 6)
                #expect(tree.nodes(forTier: 1).count == 2)
                #expect(tree.nodes(forTier: 2).count == 2)
                #expect(tree.nodes(forTier: 3).count == 2)
            }
        }
    }

    @Test func expectedHeroKeywordAffinitiesAndTreeNamesMatch() {
        let knight = CombatantTalentCatalog.config(for: "knight")
        #expect(knight.trees.map(\.keyword) == [.block, .holy, .stun])
        #expect(knight.trees.map(\.name) == ["Chivalry", "Devotion", "Crusade"])

        let rogue = CombatantTalentCatalog.config(for: "rogue")
        #expect(rogue.trees.map(\.keyword) == [.poison, .bleed, .gold])
        #expect(rogue.trees.map(\.name) == ["Venom", "Laceration", "Cutpurse"])

        let wizard = CombatantTalentCatalog.config(for: "wizard")
        #expect(wizard.trees.map(\.keyword) == [.freeze, .burn, .mana])
        #expect(wizard.trees.map(\.name) == ["Cryomancy", "Pyromancy", "Arcana"])

        let ranger = CombatantTalentCatalog.config(for: "ranger")
        #expect(ranger.trees.map(\.keyword) == [.poison, .burn, .bleed])
        #expect(ranger.trees.map(\.name) == ["Nightshade", "Wildfire", "Marksmanship"])

        let warlock = CombatantTalentCatalog.config(for: "warlock")
        #expect(warlock.trees.map(\.keyword) == [.burn, .leech, .mana])
        #expect(warlock.trees.map(\.name) == ["Hellfire", "Siphon", "Occult"])

        let frostWhelp = CombatantTalentCatalog.config(for: "frost_whelp")
        #expect(frostWhelp.trees.map(\.keyword) == [.freeze, .mana, .dodge])
        #expect(frostWhelp.trees.map(\.name) == ["Rime", "Anima", "Flight"])

        let pixie = CombatantTalentCatalog.config(for: "pixie")
        #expect(pixie.trees.map(\.keyword) == [.cleanse, .health, .holy])
        #expect(pixie.trees.map(\.name) == ["Purification", "Blessing", "Luminescence"])

        let owl = CombatantTalentCatalog.config(for: "library_owl")
        #expect(owl.trees.map(\.keyword) == [.holy, .cleanse, .health])
        #expect(owl.trees.map(\.name) == ["Illumination", "Erudition", "Sanctuary"])
    }

    @Test func all324TalentNodesAreAuthored() {
        let authoredIDs = Set(CombatantTalentCatalog.signatureTalents.keys)
        #expect(authoredIDs.count == 324)

        var generatedIDs = Set<String>()
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            generatedIDs.formUnion(CombatantTalentCatalog.validNodeIDs(for: combatantID))
        }
        #expect(generatedIDs.count == 324)
        #expect(authoredIDs == generatedIDs)
    }

    @Test func noPlaceholderTalentNodesRemain() {
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            let config = CombatantTalentCatalog.config(for: combatantID)
            for tree in config.trees {
                for node in tree.nodes {
                    #expect(!node.description.contains("Augments"), "placeholder description remains for \(node.id)")
                    #expect(!node.name.contains("Adept"), "placeholder name remains for \(node.id)")
                    #expect(!node.name.contains("Focus "), "placeholder name remains for \(node.id)")
                    #expect(!node.name.contains("Mastery "), "placeholder name remains for \(node.id)")
                }
            }
        }
    }

    @Test func talentDisplayNamesAreUnique() {
        var names: [String: String] = [:]
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            let config = CombatantTalentCatalog.config(for: combatantID)
            for tree in config.trees {
                for node in tree.nodes {
                    #expect(names[node.name] == nil, "duplicate talent name \(node.name) at \(node.id)")
                    names[node.name] = node.id
                }
            }
        }
    }

    @Test func catalogTriggersMerge() {
        let t = CombatantTalentCatalog.triggers(for: ["lizard_scout_poison_t1_1"])
        #expect(t.dodgeApplyPoison == 2)
    }

    @Test func everyAuthoredTalentHasMechanics() {
        for (id, effect) in CombatantTalentCatalog.signatureTalents {
            #expect(
                !effect.modifiers.isEmpty || effect.triggers != CombatTraitTriggers(),
                "inert talent \(id) (\(effect.name))"
            )
        }
    }
}
