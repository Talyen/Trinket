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

    @Test func allTalentNodesHaveAuthoredSymbols() {
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            let config = CombatantTalentCatalog.config(for: combatantID)
            for tree in config.trees {
                for node in tree.nodes {
                    #expect(node.symbolName != nil && !(node.symbolName?.isEmpty ?? true), "missing symbol on node \(node.id)")
                    if let effect = CombatantTalentCatalog.effect(for: node.id) {
                        #expect(!effect.symbolName.isEmpty, "missing symbol on effect \(node.id)")
                    } else {
                        Issue.record("missing effect for \(node.id)")
                    }
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

    @Test func triggerFamilyFieldNamesAreUnique() {
        let names = CombatTraitTriggers.allFieldNames
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
    }

    @Test func boolTalentFlagsSurviveMergeIntoEmptyProfile() {
        var merged = CombatTraitTriggers()
        merged.merge(CombatTraitTriggers(gold: GoldTriggers(goldDoubledWhileFullHealth: true)))
        merged.merge(CombatTraitTriggers(attack: AttackTriggers(criticalPurgeAll: true)))
        #expect(merged.goldDoubledWhileFullHealth)
        #expect(merged.criticalPurgeAll)
    }

    @Test func starterEligibilityMatchesEveryHeroAndCompanionInCatalogOrder() {
        #expect(GameContent.starterHeroes == GameContent.heroes)
        #expect(GameContent.starterHeroIDs == GameContent.heroes.map(\.id))
        #expect(GameContent.starterCompanions == GameContent.companions)
        #expect(GameContent.starterCompanionIDs == GameContent.companions.map(\.id))

        let allStarters = GameContent.starterHeroes + GameContent.starterCompanions
        for combatant in allStarters {
            let affinities = CombatantTalentCatalog.combatantTreeAffinities[combatant.id]
            #expect(affinities?.count == 3, "\(combatant.id) must have exactly 3 authored tree affinities")
        }
    }

    @Test func treeAffinityKeysMatchHeroAndCompanionRoster() {
        let rosterIDs = Set((GameContent.heroes + GameContent.companions).map(\.id))
        #expect(Set(CombatantTalentCatalog.combatantTreeAffinities.keys) == rosterIDs)
    }
}
