import Foundation
import TrinketCore

/// Hand-authored Spires catalog (v1 damage set). Floor enemies reuse the existing enemy roster.
enum SpireCatalog {
    static let spires: [SpireDefinition] = [
        SpireDefinition(
            id: .ironVein,
            title: "Iron Vein",
            epithet: "Strike without ornament",
            keyword: .physical
        ),
        SpireDefinition(
            id: .cinderSpire,
            title: "Cinder Spire",
            epithet: "Heat that refuses to die",
            keyword: .burn
        ),
        SpireDefinition(
            id: .serpentHollow,
            title: "Serpent Hollow",
            epithet: "Slow certainty",
            keyword: .poison
        ),
        SpireDefinition(
            id: .scarGallery,
            title: "Scar Gallery",
            epithet: "Every cut remembers",
            keyword: .bleed
        ),
        SpireDefinition(
            id: .aureateChoir,
            title: "Aureate Choir",
            epithet: "Light that judges",
            keyword: .holy
        ),
        SpireDefinition(
            id: .rimeVault,
            title: "Rime Vault",
            epithet: "Stillness that binds",
            keyword: .freeze
        ),
        SpireDefinition(
            id: .stormAnvil,
            title: "Storm Anvil",
            epithet: "One blow that stops the world",
            keyword: .stun
        )
    ]

    static let spiresByID: [SpireID: SpireDefinition] = Dictionary(uniqueKeysWithValues: spires.map { ($0.id, $0) })

    static func spire(id: SpireID) -> SpireDefinition? {
        spiresByID[id]
    }

    static func floors(for spireID: SpireID) -> [SpireFloor] {
        floorsBySpireID[spireID] ?? []
    }

    static func floor(spireID: SpireID, floor: Int) -> SpireFloor? {
        floors(for: spireID).first { $0.floor == floor }
    }

    /// Preferred enemy IDs per Spire keyword, ordered for floors 1…n (boss last when possible).
    /// Prefer enemies whose kits include the Spire keyword; fall back to thematic roster fills.
    private static let enemyPools: [Keyword: [String]] = [
        .physical: ["goblin", "skeleton", "slime", "mimic", "the_iron_bear"],
        .burn: ["will_o_wisp", "fire_elemental", "the_forge_golem"],
        .poison: ["plague_doctor", "necromancer", "the_blight_treant"],
        .bleed: ["mimic", "necromancer", "the_blight_treant"],
        .holy: ["skeleton", "living_armor", "the_iron_bear"],
        .freeze: ["frost_elemental", "the_frostwarden"],
        .stun: ["goblin", "living_armor", "the_forge_golem"]
    ]

    private static let floorsBySpireID: [SpireID: [SpireFloor]] = {
        var result: [SpireID: [SpireFloor]] = [:]
        for spire in spires {
            let pool = enemyPools[spire.keyword] ?? ["goblin", "skeleton", "slime"]
            var floors: [SpireFloor] = []
            for floorIndex in 1 ... spire.floorCount {
                let isFinalFloor = floorIndex == spire.floorCount
                let enemyID: String = if isFinalFloor {
                    pool.last ?? "goblin"
                } else {
                    pool[(floorIndex - 1) % max(pool.count - 1, 1)]
                }
                floors.append(
                    SpireFloor(
                        spireID: spire.id,
                        floor: floorIndex,
                        enemyID: enemyID
                    )
                )
            }
            result[spire.id] = floors
        }
        return result
    }()
}

public extension GameContent {
    static var spires: [SpireDefinition] {
        SpireCatalog.spires
    }

    static func spire(id: SpireID) -> SpireDefinition? {
        SpireCatalog.spire(id: id)
    }

    static func spireFloors(for spireID: SpireID) -> [SpireFloor] {
        SpireCatalog.floors(for: spireID)
    }

    static func spireFloor(spireID: SpireID, floor: Int) -> SpireFloor? {
        SpireCatalog.floor(spireID: spireID, floor: floor)
    }
}
