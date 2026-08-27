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
            id: .sanguineCourt,
            title: "Sanguine Court",
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
            id: .resonanceHall,
            title: "Resonance Hall",
            epithet: "One blow that stops the world",
            keyword: .stun
        ),
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
        .physical: ["goblin", "bandit", "ogre", "living_armor", "the_iron_bear"],
        .burn: ["fire_imp", "hellhound", "fire_elemental", "pyromancer", "the_forge_golem"],
        .poison: ["giant_spider", "giant_snake", "slime", "plague_doctor", "the_blight_treant"],
        .bleed: ["blood_cultist", "dire_wolf", "vampire", "necromancer", "the_blood_countess"],
        .holy: ["zealot", "cleric", "inquisitor", "paladin", "the_seraph"],
        .freeze: ["winter_wolf", "frost_elemental", "ice_wraith", "yeti", "the_frostwarden"],
        .stun: ["banshee", "brawler", "stone_golem", "earth_elemental", "the_stone_titan"],
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
