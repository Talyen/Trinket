import Foundation
import TrinketCore

public enum LabyrinthCatalog {
    public static let modifiers: [LabyrinthModifierDefinition] = [
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ironPressure"),
            title: "Iron Pressure",
            effect: .damageDealt(keyword: .physical, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ashTithe"),
            title: "Ash Tithe",
            effect: .damageDealt(keyword: .burn, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bloodMarket"),
            title: "Blood Market",
            effect: .damageDealt(keyword: .bleed, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("serpentBloom"),
            title: "Serpent Bloom",
            effect: .damageDealt(keyword: .poison, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("rimeTax"),
            title: "Rime Tax",
            effect: .damageDealt(keyword: .freeze, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("sunTithe"),
            title: "Sun Tithe",
            effect: .damageDealt(keyword: .holy, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("concussionToll"),
            title: "Concussion Toll",
            effect: .damageDealt(keyword: .stun, amount: 1),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bulwarkBargain"),
            title: "Bulwark Bargain",
            effect: .blockGained(2),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("vampiricLedger"),
            title: "Vampiric Ledger",
            effect: .leechGainedPercent(5),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("wardedFlesh"),
            title: "Warded Flesh",
            effect: .damageTakenReduction(keyword: .physical, percent: 20),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("frostboundWard"),
            title: "Frostbound Ward",
            effect: .damageTakenReduction(keyword: .freeze, percent: 30),
            nodeTypes: [.battle, .boss]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bountyMark"),
            title: "Bounty Mark",
            effect: .goldFoundPercent(25),
            nodeTypes: [.battle, .boss, .mystery]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("scholarsToll"),
            title: "Scholar's Toll",
            effect: .experienceEarnedPercent(25),
            nodeTypes: [.battle, .boss, .mystery]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("scavengersLuck"),
            title: "Scavenger's Luck",
            effect: .materialsFoundPercent(25),
            nodeTypes: [.battle, .boss, .mystery]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("shopDiscount"),
            title: "Shop Discount",
            effect: .shopDiscountPercent(10),
            nodeTypes: [.shop]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("appraisersEye"),
            title: "Appraiser's Eye",
            effect: .astralShopOffers,
            nodeTypes: [.shop]
        ),
    ]

    public static let modifiersByID: [LabyrinthModifierID: LabyrinthModifierDefinition] =
        Dictionary(uniqueKeysWithValues: modifiers.map { ($0.id, $0) })

    public static var trashEnemyIDs: [String] {
        GameContent.enemies.filter { !$0.isBoss }.map(\.id)
    }

    public static var bossEnemyIDs: [String] {
        GameContent.enemies.filter(\.isBoss).map(\.id)
    }

    public static func modifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        modifiersByID[id]
    }

    public static func modifiers(ids: [LabyrinthModifierID]) -> [LabyrinthModifierDefinition] {
        ids.compactMap { modifiersByID[$0] }
    }

    public static func enemyDamageKeywords(for enemyID: String) -> Set<Keyword> {
        guard let enemy = GameContent.enemy(matching: enemyID) else { return [] }
        return Set(enemy.combatant.abilities.flatMap(\.keywords))
    }

    public static func combatModifiers(
        for enemyID: String,
        nodeType: LabyrinthNodeType
    ) -> [LabyrinthModifierDefinition] {
        guard nodeType.isCombat else { return [] }
        let keywords = enemyDamageKeywords(for: enemyID)
        return modifiers.filter { modifier in
            guard modifier.applies(to: nodeType) else { return false }
            guard let keyword = modifier.relevantKeyword else { return true }
            return keywords.contains(keyword)
        }
    }

    public static func modifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        worldSeed: UInt64,
        nodeID: String
    ) -> [LabyrinthModifierID] {
        let pool: [LabyrinthModifierDefinition] = switch type.canonical {
        case .battle, .boss:
            enemyID.map { combatModifiers(for: $0, nodeType: type) } ?? []
        case .shop:
            modifiers.filter { $0.applies(to: .shop) }
        case .mystery:
            modifiers.filter { $0.applies(to: .mystery) }
        case .rest, .event, .recruit, .craft, .entrance:
            []
        }
        guard !pool.isEmpty else { return [] }
        let index = Int(
            GameContent.encounterSeed(worldSeed, salt: "labyrinth-modifier-\(nodeID)")
                % UInt64(pool.count)
        )
        return [pool[index].id]
    }

    public static func pickBossEnemyID(
        excluding previousBossID: String?,
        using rng: inout some RandomNumberGenerator
    ) -> String {
        let pool = bossEnemyIDs.filter { $0 != previousBossID }
        let choices = pool.isEmpty ? bossEnemyIDs : pool
        return choices.randomElement(using: &rng) ?? bossEnemyIDs[0]
    }

    public static func pickTrashEnemyID(using rng: inout some RandomNumberGenerator) -> String {
        trashEnemyIDs.randomElement(using: &rng) ?? trashEnemyIDs[0]
    }

    public static func resolvedModifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        existingModifierIDs: [LabyrinthModifierID],
        worldSeed: UInt64,
        nodeID: String
    ) -> [LabyrinthModifierID] {
        let applicable: [LabyrinthModifierDefinition] = switch type.canonical {
        case .battle, .boss:
            if let enemyID {
                combatModifiers(for: enemyID, nodeType: type)
            } else {
                []
            }
        case .shop, .mystery:
            modifiers.filter { $0.applies(to: type) }
        default:
            []
        }
        if let existing = existingModifierIDs.compactMap({ id in
            applicable.first { $0.id == id }
        }).first {
            return [existing.id]
        }
        guard !applicable.isEmpty else { return [] }
        return modifierIDs(for: type, enemyID: enemyID, worldSeed: worldSeed, nodeID: nodeID)
    }

    public static func fallbackBossEnemyID(worldSeed: UInt64, nodeID: String) -> String {
        let pool = bossEnemyIDs
        let index = Int(
            GameContent.encounterSeed(worldSeed, salt: "labyrinth-boss-\(nodeID)") % UInt64(pool.count)
        )
        return pool[index]
    }
}

public extension GameContent {
    static var labyrinthModifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers
    }

    static func labyrinthModifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        LabyrinthCatalog.modifier(id: id)
    }
}
