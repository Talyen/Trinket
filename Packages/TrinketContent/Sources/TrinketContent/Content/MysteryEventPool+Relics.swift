import Foundation
import TrinketCore

extension MysteryEventPool {
    static let ancientAltar = makeEvent(
        id: "ancient-altar",
        title: "Ancient Altar",
        narrative: "Merchants have left {A} and coins in an offering bowl. Beneath the altar, rusted iron chains bind {B}.",
        artID: "mystery-ancient-altar",
        choices: [
            ("take-the-offering", "Collect Tribute", [
                item("topaz_amulet", trinkets: ["merchants_favor"]),
                .gainGold(20),
            ]),
            ("claim-the-relic", "Free the Relic", [
                item("flail", uniques: ["wardbreaker"]),
                .gainMaterial(.iron),
            ]),
        ],
    )

    static let hiddenCache = makeEvent(
        id: "hidden-cache",
        title: "Hidden Cache",
        narrative: "A leather pack lies beneath exposed roots. {A} rests across a coinpurse; {B} is tucked into the pack’s torn hide lining.",
        artID: "mystery-hidden-cache",
        choices: [
            ("take-coinpurse", "Take the Purse", [
                item("dagger", trinkets: ["cutpurse_knife"]),
                .gainGold(20),
            ]),
            ("claim-blade", "Search the Pack", [
                item("shortsword", trinkets: ["smugglers_map"]),
                .gainMaterial(.hide),
            ]),
        ],
    )

    static let overgrownTemple = makeEvent(
        id: "overgrown-temple",
        title: "Overgrown Temple",
        narrative: "Burial coins surround {A} in the vine-choked crypt. Nearby, fallen masonry pins {B} beside a broken sarcophagus.",
        artID: "mystery-overgrown-temple",
        choices: [
            ("search-the-crypt", "Search the Crypt", [
                item("topaz_amulet", trinkets: ["sin_eaters_lantern"]),
                .gainGold(20),
            ]),
            ("take-a-tile", "Clear the Rubble", [
                item("plate_armor", uniques: ["saintfall_plate"]),
                .gainMaterial(.stone),
            ]),
        ],
    )

    static let abandonedStudy = makeEvent(
        id: "abandoned-study",
        title: "Abandoned Study",
        narrative: "An unfinished spell surrounds {A} on the desk. Across the room, {B} glints through a splintered wooden cabinet.",
        artID: "mystery-abandoned-study",
        choices: [
            ("search-scrolls", "Study the Spell", [
                item("wand", trinkets: ["runic_quill"]),
                .gainExperience,
            ]),
            ("take-the-quill", "Open the Cabinet", [
                item("sapphire_amulet", trinkets: ["frozen_pocketwatch"]),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let mysteriousTome = makeEvent(
        id: "mysterious-tome",
        title: "Mysterious Tome",
        narrative: "The floating tome’s loose leaves circle {A}, revealing fragments of a lost spell. Beside the pedestal, a crystal seal imprisons {B}.",
        artID: "mystery-mysterious-tome",
        choices: [
            ("take-the-pages", "Study the Pages", [
                item("spellbook", trinkets: ["tattered_pages"]),
                .gainExperience,
            ]),
            ("repair-the-binding", "Break the Seal", [
                item("staff", uniques: ["twin_casting"]),
                .gainMaterial(.crystal),
            ]),
        ],
    )

    static let crystalGeode = makeEvent(
        id: "crystal-geode",
        title: "Crystal Geode",
        narrative: "A split geode reveals {A} among its glittering crystals. {B} remains lodged in the thick stone shell.",
        artID: "mystery-crystal-geode",
        choices: [
            ("collect-gems", "Collect Gems", [
                item("sapphire_ring", guaranteedAffixIDs: ["manabound"]),
                .gainMaterial(.crystal),
            ]),
            ("take-the-shell", "Break the Shell", [
                item("topaz_amulet", trinkets: ["sundering_charm"]),
                .gainMaterial(.stone),
            ]),
        ],
    )

    static let meteoriteCrash = makeEvent(
        id: "meteorite-crash",
        title: "Meteorite Crash",
        narrative: "{A} glows inside the meteorite’s cracked iron shell. The impact has collapsed a stone shelter, burying {B} beneath its rubble.",
        artID: "mystery-meteorite-crash",
        choices: [
            ("take-a-fragment", "Open the Core", [
                item("ruby_amulet", trinkets: ["meteorite"]),
                .gainMaterial(.iron),
            ]),
            ("search-the-crater", "Search the Ruins", [
                item("maul", trinkets: ["obsidian_hammer"]),
                .gainMaterial(.stone),
            ]),
        ],
    )

    static let forgottenHoard = makeEvent(
        id: "forgotten-hoard",
        title: "Forgotten Hoard",
        narrative: "An enormous skeleton curls around its hoard. {A} lies among ribs and rusted iron; {B} guards a spill of gold coins.",
        artID: "mystery-forgotten-hoard",
        choices: [
            ("collect-the-bones", "Search the Bones", [
                item("ruby_amulet", trinkets: ["bone_charm"]),
                .gainMaterial(.iron),
            ]),
            ("claim-the-shield", "Recover the Hoard", [
                item("kite_shield", trinkets: ["vanguards_crest"]),
                .gainGold(30),
            ]),
        ],
    )

    static let necromancersOffer = makeEvent(
        id: "necromancers-offer",
        title: "The Necromancer's Offer",
        narrative: "The necromancer offers {A} with a lesson in forbidden rites. Their other hand presents {B}, resting in a bowl of crystal salts.",
        artID: "mystery-the-necromancers-offer",
        choices: [
            ("accept-rite", "Learn the Rite", [
                item("staff"),
                .gainExperience,
            ]),
            ("take-the-salts", "Take the Salts", [
                item("ruby_amulet", trinkets: ["bone_charm"]),
                .gainMaterial(.crystal),
            ]),
        ],
    )

    static let huntersLodge = makeEvent(
        id: "hunters-lodge",
        title: "Hunter's Lodge",
        narrative: "Inside the deserted lodge, {A} hangs beside spare leather straps. Outside, {B} rests in a chopping block surrounded by split logs.",
        artID: "mystery-hunters-lodge",
        choices: [
            ("claim-the-bow", "Take the Weapon", [
                item("crossbow", uniques: ["blackfletch"]),
                .gainMaterial(.hide),
            ]),
            ("take-the-hatchet", "Gather the Tools", [
                item("hatchet"),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let roadsideCenser = makeEvent(
        id: "roadside-censer",
        title: "Roadside Censer",
        narrative: "A roadside shrine holds {A} beside bundles of incense herbs. Beneath its hanging censer, {B} rests among pilgrims’ coins.",
        artID: "mystery-roadside-censer",
        choices: [
            ("gather-incense", "Gather Incense", [
                item("topaz_amulet", trinkets: ["brass_censer"]),
                .gainMaterial(.herbs),
            ]),
            ("claim-censer", "Take the Offering", [
                item("topaz_ring", uniques: ["golden_verdict"]),
                .gainGold(20),
            ]),
        ],
    )

    static let corruptionAltar = makeEvent(
        id: Self.corruptionAltarID,
        title: "Corruption Altar",
        narrative: "A cracked stone altar bleeds violet light from its seams. Offer an item and the altar remakes it without mercy, for better or worse, then seals it as Corrupted forever. You may also walk away untouched.",
        artID: "destination-corruption-altar",
        choices: [
            ("corrupt-item", "Corrupt an Item", [.corruptItem]),
            ("leave", "Leave", [.leave]),
        ],
    )
}
