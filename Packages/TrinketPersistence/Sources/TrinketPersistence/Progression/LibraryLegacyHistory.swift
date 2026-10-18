import TrinketContent

/// Frozen against distributed wire-v18 content. Never substitute current catalog
/// enemies for historical random encounters or retired offers.
enum LibraryLegacyHistory {
    private static let stages: [String: String] = [
        "chapter-1-stage-1": "slime",
        "chapter-1-stage-3": "mud_elemental",
        "chapter-1-stage-6": "goblin",
        "chapter-1-stage-8": "will_o_wisp",
        "chapter-1-stage-10": "the_blight_treant",
        "chapter-2-stage-1": "skeleton",
        "chapter-2-stage-3": "mimic",
        "chapter-2-stage-5": "necromancer",
        "chapter-2-stage-7": "living_armor",
        "chapter-2-stage-10": "the_iron_bear",
        "chapter-3-stage-1": "fire_elemental",
        "chapter-3-stage-10": "the_forge_golem",
        "chapter-4-stage-1": "frost_elemental",
        "chapter-4-stage-10": "the_frostwarden",
    ]

    private static let spires: [String: [String]] = [
        "ironVein": ["goblin", "bandit", "ogre", "living_armor", "the_iron_bear"],
        "cinderSpire": ["fire_imp", "hellhound", "fire_elemental", "pyromancer", "the_forge_golem"],
        "serpentHollow": ["giant_spider", "giant_snake", "slime", "plague_doctor", "the_blight_treant"],
        "sanguineCourt": ["blood_cultist", "dire_wolf", "vampire", "necromancer", "the_blood_countess"],
        "aureateChoir": ["zealot", "cleric", "inquisitor", "paladin", "the_seraph"],
        "rimeVault": ["winter_wolf", "frost_elemental", "ice_wraith", "yeti", "the_frostwarden"],
        "resonanceHall": ["banshee", "brawler", "stone_golem", "earth_elemental", "the_stone_titan"],
    ]

    static func defeatedEnemyIDs(in save: PlayerSave) -> Set<String> {
        var ids = Set(save.journey.completedStageIDs.compactMap { stages[$0] })
        for (spire, highest) in save.spires.highestClearedFloorBySpireID {
            guard let pool = spires[spire], highest > 0 else { continue }
            for floor in 1 ... min(highest, 10) {
                ids.insert(pool[floor == 10 ? 4 : (floor - 1) % 4])
            }
        }
        for node in save.labyrinth.nodes.values where node.isCleared && node.type.isCombat {
            if let id = node.enemyID {
                ids.insert(id)
            }
        }
        for node in save.voyage.activeRun?.nodes ?? [] where node.isCleared && node.type.isCombat {
            if let id = node.enemyID {
                ids.insert(id)
            }
        }
        return ids
    }
}
