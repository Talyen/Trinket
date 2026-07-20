import Foundation
import TrinketCore

/// Hand-authored The Labyrinth biomes and named node modifiers.
public enum LabyrinthCatalog {
    public static let biomes: [LabyrinthBiomeDefinition] = [
        LabyrinthBiomeDefinition(
            id: .ironGalleries,
            title: "Iron Galleries",
            epithet: "Struck stone, brute foes",
            keywordBias: .physical,
            enemyPool: ["goblin", "skeleton", "slime", "living_armor"],
            bossEnemyID: "the_iron_bear"
        ),
        LabyrinthBiomeDefinition(
            id: .cinderGalleries,
            title: "Cinder Galleries",
            epithet: "Heat that refuses to die",
            keywordBias: .burn,
            enemyPool: ["will_o_wisp", "fire_elemental", "skeleton"],
            bossEnemyID: "the_forge_golem"
        ),
        LabyrinthBiomeDefinition(
            id: .serpentSump,
            title: "Serpent Sump",
            epithet: "Slow certainty",
            keywordBias: .poison,
            enemyPool: ["plague_doctor", "slime", "goblin"],
            bossEnemyID: "the_blight_treant"
        ),
        LabyrinthBiomeDefinition(
            id: .scarCatacombs,
            title: "Scar Catacombs",
            epithet: "Every cut remembers",
            keywordBias: .bleed,
            enemyPool: ["mimic", "necromancer", "skeleton"],
            bossEnemyID: "the_blight_treant"
        ),
        LabyrinthBiomeDefinition(
            id: .aureateCrypt,
            title: "Aureate Crypt",
            epithet: "Light that judges",
            keywordBias: .holy,
            enemyPool: ["skeleton", "living_armor", "goblin"],
            bossEnemyID: "the_iron_bear"
        ),
        LabyrinthBiomeDefinition(
            id: .rimeDescent,
            title: "Rime Descent",
            epithet: "Stillness that binds",
            keywordBias: .freeze,
            enemyPool: ["frost_elemental", "skeleton", "slime"],
            bossEnemyID: "the_frostwarden"
        ),
        LabyrinthBiomeDefinition(
            id: .stormCulvert,
            title: "Storm Culvert",
            epithet: "Sudden violence",
            keywordBias: .stun,
            enemyPool: ["goblin", "living_armor", "mimic"],
            bossEnemyID: "the_forge_golem"
        ),
        LabyrinthBiomeDefinition(
            id: .gildedFault,
            title: "Gilded Fault",
            epithet: "Fortune in the dark",
            keywordBias: .gold,
            enemyPool: ["goblin", "mimic", "skeleton"],
            bossEnemyID: "the_iron_bear"
        ),
        LabyrinthBiomeDefinition(
            id: .heartwellGrotto,
            title: "Heartwell Grotto",
            epithet: "Mend and stand",
            keywordBias: .health,
            enemyPool: ["slime", "mud_elemental", "skeleton"],
            bossEnemyID: "the_blight_treant"
        )
    ]

    public static let biomesByID: [LabyrinthBiomeID: LabyrinthBiomeDefinition] =
        Dictionary(uniqueKeysWithValues: biomes.map { ($0.id, $0) })

    public static func biome(id: LabyrinthBiomeID) -> LabyrinthBiomeDefinition? {
        biomesByID[id]
    }

    // MARK: - Modifiers

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
        )
    ]

    public static let modifiersByID: [LabyrinthModifierID: LabyrinthModifierDefinition] =
        Dictionary(uniqueKeysWithValues: modifiers.map { ($0.id, $0) })

    public static func modifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        modifiersByID[id]
    }

    public static func modifiers(ids: [LabyrinthModifierID]) -> [LabyrinthModifierDefinition] {
        ids.compactMap { modifiersByID[$0] }
    }
}

public extension GameContent {
    static var labyrinthBiomes: [LabyrinthBiomeDefinition] {
        LabyrinthCatalog.biomes
    }

    static func labyrinthBiome(id: LabyrinthBiomeID) -> LabyrinthBiomeDefinition? {
        LabyrinthCatalog.biome(id: id)
    }

    static var labyrinthModifiers: [LabyrinthModifierDefinition] {
        LabyrinthCatalog.modifiers
    }

    static func labyrinthModifier(id: LabyrinthModifierID) -> LabyrinthModifierDefinition? {
        LabyrinthCatalog.modifier(id: id)
    }
}
