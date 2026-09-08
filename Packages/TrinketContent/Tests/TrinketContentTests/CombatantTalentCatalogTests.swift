import Testing
import TrinketCore
@testable import TrinketContent

struct CombatantTalentCatalogTests {
    @Test(arguments: [
        ("wildcard", Keyword.dodge, "wildcard_dodge_t3_2", "wildcard_dodge_t1_1", 3),
        ("druid", .health, "druid_health_t2_2", "druid_health_t1_1", 2),
        ("druid", .mana, "druid_mana_t2_2", "druid_mana_t1_1", 2),
    ])
    func `talent positions can move without changing identity or row prerequisites`(
        combatantID: String, keyword: Keyword, introductoryID: String, laterID: String, laterRow: Int,
    ) throws {
        let tree = try #require(CombatantTalentCatalog.config(for: combatantID).tree(for: keyword))
        let introductory = try #require(tree.nodes.first { $0.id == introductoryID })
        let later = try #require(tree.nodes.first { $0.id == laterID })
        #expect(introductory.row == 1)
        #expect(later.row == laterRow)
        #expect(tree.nodes(forRow: 1).first?.id == introductoryID)
        #expect(tree.nodes(forRow: laterRow).last?.id == laterID)
        #expect(tree.canUnlock(node: introductory, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.canUnlock(node: later, unlockedNodeIDs: [], availablePoints: 1))
        let prerequisites = Set(tree.nodes.filter { $0.row < laterRow }.map(\.id))
        #expect(tree.canUnlock(node: later, unlockedNodeIDs: prerequisites, availablePoints: 1))
        #expect(CombatantTalentCatalog.effect(for: introductoryID)?.name == introductory.name)
    }

    @Test func `all combatants have three keywords and contiguous authored rows`() {
        let combatants = GameContent.heroes + GameContent.companions
        for combatant in combatants {
            let config = CombatantTalentCatalog.config(for: combatant.id)
            #expect(config.combatantID == combatant.id)
            #expect(config.trees.count == 3)
            for tree in config.trees {
                #expect(!tree.name.isEmpty)
                #expect(tree.nodes.count >= 7)
                #expect(tree.rows == Array(1 ... tree.rows.count))
                for row in tree.rows {
                    let nodeCount = tree.nodes(forRow: row).count
                    #expect(row <= 3 ? nodeCount == 2 : (1 ... 2).contains(nodeCount))
                }
            }
        }
    }

    @Test func `keyword affinities match catalog dictionary`() {
        for (combatantID, affinities) in CombatantTalentCatalog.combatantTreeAffinities {
            let config = CombatantTalentCatalog.config(for: combatantID)
            #expect(config.trees.map(\.keyword) == affinities.map(\.keyword))
        }
        for combatant in GameContent.heroes + GameContent.companions {
            #expect(combatant.affinityKeywords == CombatantTalentCatalog.combatantTreeAffinities[combatant.id]?.map(\.keyword) ?? [])
        }
    }

    @Test func `authored talent node I ds match generated trees`() {
        let authoredIDs = Set(CombatantTalentCatalog.signatureTalents.keys)
        var generatedIDs = Set<String>()
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            generatedIDs.formUnion(CombatantTalentCatalog.validNodeIDs(for: combatantID))
        }
        #expect(!authoredIDs.isEmpty)
        #expect(authoredIDs == generatedIDs)
    }

    @Test func `no placeholder talent nodes remain`() {
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

    @Test func `all talent nodes have authored symbols`() {
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

    @Test func `talent display names are unique`() {
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

    @Test func `catalog authored triggers resolve`() {
        let t = CombatantTalentCatalog.signatureTalents["lizard_scout_poison_t1_1"]?.triggers
        #expect(t?.dodgeApplyPoison == 2)
    }

    @Test func `sundering and holy block break match tree keywords`() {
        for combatantID in CombatantTalentCatalog.combatantTreeAffinities.keys {
            let config = CombatantTalentCatalog.config(for: combatantID)
            for tree in config.trees {
                for node in tree.nodes {
                    let effect = CombatantTalentCatalog.effect(for: node.id)
                    let triggers = effect?.triggers
                    if (triggers?.sunderingBlockMultiplier ?? 0) != 0 {
                        #expect(
                            node.keyword == .physical || node.keyword == .stun,
                            "sunderingBlockMultiplier on \(node.id) (\(node.keyword))",
                        )
                    }
                    if (triggers?.holyBlockBreakMultiplier ?? 1) != 1 {
                        #expect(node.keyword == .holy, "holyBlockBreakMultiplier on \(node.id) (\(node.keyword))")
                    }
                }
            }
        }
    }

    @Test func `every authored talent has mechanics`() {
        for (id, effect) in CombatantTalentCatalog.signatureTalents {
            #expect(
                !effect.modifiers.isEmpty || effect.triggers != CombatTraitTriggers(),
                "inert talent \(id) (\(effect.name))",
            )
        }
    }

    @Test func `trigger family field names are unique`() {
        let names = CombatTraitTriggers.allFieldNames
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
    }

    @Test func `bool talent flags survive merge into empty profile`() {
        var merged = CombatTraitTriggers()
        merged.merge(CombatTraitTriggers(gold: GoldTriggers(goldDoubledWhileFullHealth: true)))
        merged.merge(CombatTraitTriggers(attack: AttackTriggers(criticalPurgeAll: true)))
        #expect(merged.goldDoubledWhileFullHealth)
        #expect(merged.criticalPurgeAll)
    }

    @Test func `starter eligibility matches every hero and companion in catalog order`() {
        #expect(GameContent.heroes.allSatisfy { $0.role == .hero })
        #expect(GameContent.companions.allSatisfy { $0.role == .companion })

        let allStarters = GameContent.heroes + GameContent.companions
        for combatant in allStarters {
            let affinities = CombatantTalentCatalog.combatantTreeAffinities[combatant.id]
            #expect(affinities?.count == 3, "\(combatant.id) must have exactly 3 authored tree affinities")
        }
    }

    @Test func `tree affinity keys match hero and companion roster`() {
        let rosterIDs = Set((GameContent.heroes + GameContent.companions).map(\.id))
        #expect(Set(CombatantTalentCatalog.combatantTreeAffinities.keys) == rosterIDs)
    }
}
