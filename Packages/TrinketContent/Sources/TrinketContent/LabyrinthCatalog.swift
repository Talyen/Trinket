import Foundation
import TrinketCore

/// Hand-authored The Labyrinth biomes and named modifiers (player sees titles only).
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
            id: .wildrootHollow,
            title: "Wildroot Hollow",
            epithet: "Growth as weapon",
            keywordBias: .nature,
            enemyPool: ["mud_elemental", "slime", "goblin"],
            bossEnemyID: "the_blight_treant"
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

    // MARK: - Modifiers (titles only in UI)

    public static let modifiers: [LabyrinthModifierDefinition] = [
        // Threat + bounty pairs (Q10A)
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ironPressure"),
            title: "Iron Pressure",
            epithet: "The stone pushes back",
            category: .threat,
            enemyPowerPercent: 20,
            goldPercent: 20,
            xpPercent: 20
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("ashTithe"),
            title: "Ash Tithe",
            epithet: "Heat takes its cut",
            category: .affinity,
            keywordBias: .burn,
            enemyPowerPercent: 10,
            goldPercent: 10
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bloodMarket"),
            title: "Blood Market",
            epithet: "Every wound pays",
            category: .affinity,
            keywordBias: .bleed,
            enemyPowerPercent: 10,
            xpPercent: 15
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("rootboundHoard"),
            title: "Rootbound Hoard",
            epithet: "Nature keeps its gifts",
            category: .affinity,
            keywordBias: .nature,
            goldPercent: 10,
            itemDropBonusPercent: 15
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("gildedWhisper"),
            title: "Gilded Whisper",
            epithet: "Fortune in the dark",
            category: .encounter,
            keywordBias: .gold,
            goldPercent: 25,
            guaranteedNodeType: .shop
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("bossMark"),
            title: "Boss Mark",
            epithet: "Something waits below",
            category: .special,
            enemyPowerPercent: 5,
            goldPercent: 15,
            itemDropBonusPercent: 20,
            guaranteedNodeType: .boss
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("quietAltar"),
            title: "Quiet Altar",
            epithet: "A choice in the stone",
            category: .special,
            goldPercent: 5,
            guaranteedNodeType: .mystery
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("astralSeam"),
            title: "Astral Seam",
            epithet: "Rarity cracks open",
            category: .bounty,
            itemDropBonusPercent: 10,
            astralChanceBonusPercent: 25
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("forgeVein"),
            title: "Forge Vein",
            epithet: "The anvil answers",
            category: .special,
            goldPercent: 5,
            guaranteedNodeType: .craft
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("serpentBloom"),
            title: "Serpent Bloom",
            epithet: "Venom finds a way",
            category: .affinity,
            keywordBias: .poison,
            enemyPowerPercent: 10,
            xpPercent: 10
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("rimeTax"),
            title: "Rime Tax",
            epithet: "Cold keeps what it takes",
            category: .affinity,
            keywordBias: .freeze,
            enemyPowerPercent: 10,
            goldPercent: 10
        ),
        LabyrinthModifierDefinition(
            id: LabyrinthModifierID("stormToll"),
            title: "Storm Toll",
            epithet: "One blow, then silence",
            category: .affinity,
            keywordBias: .stun,
            enemyPowerPercent: 15,
            xpPercent: 10
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
