import Foundation
import TrinketCore

/// Hand-authored Aspects catalog (v1 damage set). Floor enemies reuse the existing enemy roster.
public enum AspectCatalog {
    public static let aspects: [AspectDefinition] = [
        AspectDefinition(
            id: .ironVein,
            title: "Iron Vein",
            epithet: "Strike without ornament",
            keyword: .physical
        ),
        AspectDefinition(
            id: .cinderSpire,
            title: "Cinder Spire",
            epithet: "Heat that refuses to die",
            keyword: .burn
        ),
        AspectDefinition(
            id: .serpentHollow,
            title: "Serpent Hollow",
            epithet: "Slow certainty",
            keyword: .poison
        ),
        AspectDefinition(
            id: .scarGallery,
            title: "Scar Gallery",
            epithet: "Every cut remembers",
            keyword: .bleed
        ),
        AspectDefinition(
            id: .aureateChoir,
            title: "Aureate Choir",
            epithet: "Light that judges",
            keyword: .holy
        ),
        AspectDefinition(
            id: .wildrootGrove,
            title: "Wildroot Grove",
            epithet: "Growth as weapon",
            keyword: .nature
        ),
        AspectDefinition(
            id: .rimeVault,
            title: "Rime Vault",
            epithet: "Stillness that binds",
            keyword: .freeze
        ),
        AspectDefinition(
            id: .stormAnvil,
            title: "Storm Anvil",
            epithet: "One blow that stops the world",
            keyword: .stun
        ),
    ]

    public static let aspectsByID: [AspectID: AspectDefinition] = {
        Dictionary(uniqueKeysWithValues: aspects.map { ($0.id, $0) })
    }()

    public static func aspect(id: AspectID) -> AspectDefinition? {
        aspectsByID[id]
    }

    public static func floors(for aspectID: AspectID) -> [AspectFloor] {
        floorsByAspectID[aspectID] ?? []
    }

    public static func floor(aspectID: AspectID, floor: Int) -> AspectFloor? {
        floors(for: aspectID).first { $0.floor == floor }
    }

    /// Preferred enemy IDs per Aspect keyword, ordered for floors 1…n (warden last when possible).
    private static let enemyPools: [Keyword: [String]] = [
        .physical: ["goblin", "skeleton", "slime", "living_armor", "the_iron_bear"],
        .burn: ["will_o_wisp", "fire_elemental", "the_forge_golem"],
        .poison: ["plague_doctor", "slime", "the_blight_treant"],
        .bleed: ["mimic", "necromancer", "the_blight_treant"],
        .holy: ["skeleton", "living_armor", "the_iron_bear"],
        .nature: ["mud_elemental", "slime", "the_blight_treant"],
        .freeze: ["frost_elemental", "the_frostwarden"],
        .stun: ["goblin", "living_armor", "the_forge_golem"],
    ]

    private static let floorsByAspectID: [AspectID: [AspectFloor]] = {
        var result: [AspectID: [AspectFloor]] = [:]
        for aspect in aspects {
            let pool = enemyPools[aspect.keyword] ?? ["goblin", "skeleton", "slime"]
            var floors: [AspectFloor] = []
            for floorIndex in 1 ... aspect.floorCount {
                let isWarden = floorIndex == aspect.floorCount
                let enemyID: String
                if isWarden {
                    enemyID = pool.last ?? "goblin"
                } else {
                    enemyID = pool[(floorIndex - 1) % max(pool.count - 1, 1)]
                }
                floors.append(
                    AspectFloor(
                        aspectID: aspect.id,
                        floor: floorIndex,
                        enemyID: enemyID,
                        rewards: rewards(for: floorIndex, isWarden: isWarden),
                        isWarden: isWarden
                    )
                )
            }
            result[aspect.id] = floors
        }
        return result
    }()

    private static func rewards(for floor: Int, isWarden: Bool) -> StageReward {
        let gold = 4 + floor * 2 + (isWarden ? 12 : 0)
        let materials: [ResourceAmount]
        if floor % 3 == 0 || isWarden {
            materials = [ResourceAmount(.wood, isWarden ? 3 : 1)]
        } else {
            materials = []
        }
        return StageReward(
            gold: gold,
            itemTemplateIDs: [],
            materialRewards: materials
        )
    }
}

public extension GameContent {
    static var aspects: [AspectDefinition] { AspectCatalog.aspects }

    static func aspect(id: AspectID) -> AspectDefinition? {
        AspectCatalog.aspect(id: id)
    }

    static func aspectFloors(for aspectID: AspectID) -> [AspectFloor] {
        AspectCatalog.floors(for: aspectID)
    }

    static func aspectFloor(aspectID: AspectID, floor: Int) -> AspectFloor? {
        AspectCatalog.floor(aspectID: aspectID, floor: floor)
    }
}
