import Testing
import TrinketCore
@testable import TrinketContent

struct CombatantTalentCatalogTests {
    @Test func allCombatantsHaveThreeKeywordsAndSixNodesPerTree() {
        let combatants = GameContent.heroes + GameContent.companions
        for combatant in combatants {
            let config = CombatantTalentCatalog.config(for: combatant.id)
            #expect(config.combatantID == combatant.id)
            #expect(config.trees.count == 3)
            for tree in config.trees {
                #expect(!tree.name.isEmpty)
                #expect(tree.nodes.count == 6)
                #expect(tree.nodes(forRow: 1).count == 2)
                #expect(tree.nodes(forRow: 2).count == 2)
                #expect(tree.nodes(forRow: 3).count == 2)
            }
        }
    }

    @Test func keywordAffinitiesMatchCatalogDictionary() {
        for (combatantID, affinities) in CombatantTalentCatalog.combatantTreeAffinities {
            let config = CombatantTalentCatalog.config(for: combatantID)
            #expect(config.trees.map(\.keyword) == affinities.map(\.keyword))
        }
    }

    @Test func authoredTalentNodeIDsMatchGeneratedTrees() {
        let authoredIDs = Set(CombatantTalentCatalog.signatureTalents.keys)
        var generatedIDs = Set<String>()
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            generatedIDs.formUnion(CombatantTalentCatalog.validNodeIDs(for: combatantID))
        }
        #expect(!authoredIDs.isEmpty)
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

    @Test func catalogAuthoredTriggersResolve() {
        let t = CombatantTalentCatalog.signatureTalents["lizard_scout_poison_t1_1"]?.triggers
        #expect(t?.dodgeApplyPoison == 2)
    }

    @Test func sunderingAndHolyBlockBreakMatchTreeKeywords() {
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            let config = CombatantTalentCatalog.config(for: combatantID)
            for tree in config.trees {
                for node in tree.nodes {
                    let effect = CombatantTalentCatalog.effect(for: node.id)
                    let triggers = effect?.triggers
                    if (triggers?.sunderingBlockMultiplier ?? 0) != 0 {
                        #expect(
                            node.keyword == .physical || node.keyword == .stun,
                            "sunderingBlockMultiplier on \(node.id) (\(node.keyword))"
                        )
                    }
                    if (triggers?.holyBlockBreakMultiplier ?? 1) != 1 {
                        #expect(node.keyword == .holy, "holyBlockBreakMultiplier on \(node.id) (\(node.keyword))")
                    }
                }
            }
        }
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
