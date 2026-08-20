import Foundation
import TrinketCore

/// Hand-authored named node modifiers for The Labyrinth.
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
            id: LabyrinthModifierID("gildedWhisper"),
            title: "Gilded Whisper",
            effect: .goldRewardPercent(10),
            nodeTypes: [.shop]
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("astralSeam"),
            title: "Astral Seam",
            effect: .astralChancePercent(25),
            nodeTypes: [.craft]
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
            guard modifier.applies(to: nodeType),
                  let keyword = modifier.damageDealtKeyword
            else { return false }
            return keywords.contains(keyword)
        }
    }

    public static func modifierIDs(
        for type: LabyrinthNodeType,
        enemyID: String?,
        worldSeed: UInt64,
        nodeID: String
    ) -> [LabyrinthModifierID] {
        switch type.canonical {
        case .battle, .boss:
            guard let enemyID else { return [] }
            let pool = combatModifiers(for: enemyID, nodeType: type)
            guard !pool.isEmpty else { return [] }
            let index = Int(
                GameContent.encounterSeed(worldSeed, salt: "labyrinth-modifier-\(nodeID)")
                    % UInt64(pool.count)
            )
            return [pool[index].id]
        case .shop:
            return [LabyrinthModifierID("gildedWhisper")]
        case .craft:
            return [LabyrinthModifierID("astralSeam")]
        case .rest, .mystery, .event, .recruit, .entrance:
            return []
        }
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
        case .shop, .craft:
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
