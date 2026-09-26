import Foundation
import TrinketCore

enum SpireCatalog {
    private static func spire(_ id: SpireID, _ title: String, _ epithet: String, _ keyword: Keyword) -> SpireDefinition {
        SpireDefinition(id: id, title: title, epithet: epithet, keyword: keyword)
    }

    static let spires: [SpireDefinition] = [
        spire(.ironVein, "Iron Vein", "Strike without ornament", .physical),
        spire(.cinderSpire, "Cinder Spire", "Heat that refuses to die", .burn),
        spire(.serpentHollow, "Serpent Hollow", "Slow certainty", .poison),
        spire(.sanguineCourt, "Sanguine Court", "Every cut remembers", .bleed),
        spire(.aureateChoir, "Aureate Choir", "Light that judges", .holy),
        spire(.rimeVault, "Rime Vault", "Stillness that binds", .freeze),
        spire(.resonanceHall, "Resonance Hall", "One blow that stops the world", .stun),
    ]

    static let spiresByID: [SpireID: SpireDefinition] = Dictionary(uniqueKeysWithValues: spires.map { ($0.id, $0) })

    static func spire(id: SpireID) -> SpireDefinition? {
        spiresByID[id]
    }

    static func floors(for spireID: SpireID) -> [SpireFloor] {
        floorsBySpireID[spireID] ?? []
    }

    static func floor(spireID: SpireID, floor: Int) -> SpireFloor? {
        let allFloors = floors(for: spireID)
        guard floor >= 1, floor <= allFloors.count else { return nil }
        return allFloors[floor - 1]
    }

    static func modifier(for floor: SpireFloor, worldSeed: UInt64) -> NodeModifierDefinition? {
        guard let spire = spire(id: floor.spireID) else { return nil }
        let nodeType: LabyrinthNodeType = floor.floor.isMultiple(of: 10) || floor.floor == spire.floorCount ? .boss : .battle
        let pool = NodeModifierCatalog.keywordModifiers(for: spire.keyword, nodeType: nodeType)
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(
            worldSeed,
            salt: "spire-modifier-\(floor.spireID.rawValue)-\(floor.floor)",
        ))
        return pool.randomElement(using: &rng)
    }

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
                let isBossFloor = floorIndex.isMultiple(of: 10) || floorIndex == spire.floorCount
                let enemyID: String = if isBossFloor {
                    pool.last ?? "goblin"
                } else {
                    pool[(floorIndex - 1) % max(pool.count - 1, 1)]
                }
                floors.append(SpireFloor(spireID: spire.id, floor: floorIndex, enemyID: enemyID))
            }
            result[spire.id] = floors
        }
        return result
    }()
}
