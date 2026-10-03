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

    @Test func `every combatant has complete authored talent trees`() throws {
        let rosterIDs = Set(GameContent.combatants.map(\.id))
        #expect(Set(CombatantTalentCatalog.combatantTreeAffinities.keys) == rosterIDs)
        var nodeIDs: Set<String> = []
        var names: Set<String> = []
        for combatant in GameContent.combatants {
            let config = CombatantTalentCatalog.config(for: combatant.id)
            #expect(config.combatantID == combatant.id)
            #expect(config.trees.count == 3)
            #expect(config.trees.map(\.keyword) == combatant.affinityKeywords)
            for tree in config.trees {
                #expect(!tree.name.isEmpty)
                #expect(tree.nodes.count >= 7)
                #expect(tree.rows == Array(1 ... tree.rows.count))
                for row in tree.rows {
                    let count = tree.nodes(forRow: row).count
                    #expect(row <= 3 ? count == 2 : (1 ... 2).contains(count))
                }
                for node in tree.nodes {
                    #expect(nodeIDs.insert(node.id).inserted, "Duplicate talent ID \(node.id)")
                    #expect(names.insert(node.name).inserted, "Duplicate talent name \(node.name)")
                    let effect = try #require(CombatantTalentCatalog.effect(for: node.id))
                    #expect(node.iconID != nil && !(node.iconID?.isEmpty ?? true), "Missing icon on \(node.id)")
                    #expect(!effect.iconID.isEmpty, "Missing icon on effect \(node.id)")
                    #expect(!effect.modifiers.isEmpty || effect.triggers != CombatTraitTriggers(), "Inert talent \(node.id)")
                    if effect.triggers.sunderingBlockMultiplier != 0 {
                        #expect(node.keyword == .physical || node.keyword == .stun, "Sundering on \(node.id)")
                    }
                    if effect.triggers.holyBlockBreakMultiplier != 1 {
                        #expect(node.keyword == .holy, "Holy Block break on \(node.id)")
                    }
                }
            }
            #expect(CombatantTalentCatalog.validNodeIDs(for: combatant.id) == Set(config.trees.flatMap(\.nodes).map(\.id)))
        }
        #expect(!nodeIDs.isEmpty)
        #expect(nodeIDs == Set(CombatantTalentCatalog.signatureTalents.keys))
    }

    @Test func `catalog authored triggers resolve`() {
        let t = CombatantTalentCatalog.signatureTalents["lizard_scout_poison_t1_1"]?.triggers
        #expect(t?.dodgeApplyPoison == 2)
    }

    @Test func `bool talent flags survive merge into empty profile`() {
        var merged = CombatTraitTriggers()
        merged.merge(CombatTraitTriggers(gold: GoldTriggers(goldDoubledWhileFullHealth: true)))
        merged.merge(CombatTraitTriggers(attack: AttackTriggers(criticalPurgeAll: true)))
        #expect(merged.goldDoubledWhileFullHealth)
        #expect(merged.criticalPurgeAll)
    }
}
