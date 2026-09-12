import Foundation
import TrinketCore

extension MysteryEventPool {
    static let ancientAltar = makeEvent(
        id: "ancient-altar",
        title: "Ancient Altar",
        narrative: "An offering bowl holds {A} while rusted chains bind {B} below.",
        artID: "mystery-ancient-altar",
        choices: [
            ("take-the-offering", "Collect Tribute", [
                item("topaz_amulet", trinkets: ["merchants_favor"], uniques: ["the_golden_crucible"]),
                .gainGold(20),
            ]),
            ("claim-the-relic", "Free the Relic", [
                item("flail", uniques: ["wardbreaker", "everkeen"]),
                .gainMaterial(.iron),
            ]),
        ],
    )

    static let hiddenCache = makeEvent(
        id: "hidden-cache",
        title: "Hidden Cache",
        narrative: "A coinpurse rests beneath {A} as torn leather conceals {B}.",
        artID: "mystery-hidden-cache",
        choices: [
            ("take-coinpurse", "Take the Purse", [
                item("dagger", trinkets: ["cutpurse_knife"]),
                .gainGold(20),
            ]),
            ("claim-blade", "Search the Pack", [
                item("shortsword", trinkets: ["smugglers_map"], uniques: ["the_patient_edge"]),
                .gainMaterial(.hide),
            ]),
        ],
    )

    static let overgrownTemple = makeEvent(
        id: "overgrown-temple",
        title: "Overgrown Temple",
        narrative: "Burial coins surround {A} while fallen masonry pins {B} beside the crypt.",
        artID: "mystery-overgrown-temple",
        choices: [
            ("search-the-crypt", "Search the Crypt", [
                item("topaz_amulet", trinkets: ["sin_eaters_lantern"]),
                .gainGold(20),
            ]),
            ("take-a-tile", "Clear the Rubble", [
                item("plate_armor", uniques: ["saintfall_plate", "oathkeeper"]),
                .gainMaterial(.stone),
            ]),
        ],
    )

    static let abandonedStudy = makeEvent(
        id: "abandoned-study",
        title: "Abandoned Study",
        narrative: "An unfinished spell surrounds {A}, and a splintered cabinet hides {B}.",
        artID: "mystery-abandoned-study",
        choices: [
            ("search-scrolls", "Study the Spell", [
                item("wand", trinkets: ["runic_quill"], uniques: ["the_final_spark"]),
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
        narrative: "Loose pages reveal {A} while a crystal seal imprisons {B}.",
        artID: "mystery-mysterious-tome",
        choices: [
            ("take-the-pages", "Study the Pages", [
                item("spellbook", trinkets: ["tattered_pages"], uniques: ["threefold_grace"]),
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
        narrative: "Glittering crystals reveal {A} while thick stone grips {B}.",
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
        narrative: "The meteorite’s core cradles {A} as its impact buries {B} in stone.",
        artID: "mystery-meteorite-crash",
        choices: [
            ("take-a-fragment", "Open the Core", [
                item("ruby_amulet", trinkets: ["meteorite"], uniques: ["bloodember_pendant"]),
                .gainMaterial(.iron),
            ]),
            ("search-the-crater", "Search the Ruins", [
                item("maul", trinkets: ["obsidian_hammer"], uniques: ["kingbreaker"]),
                .gainMaterial(.stone),
            ]),
        ],
    )

    static let forgottenHoard = makeEvent(
        id: "forgotten-hoard",
        title: "Forgotten Hoard",
        narrative: "An ancient skeleton guards {A} while gold coins spill around {B}.",
        artID: "mystery-forgotten-hoard",
        choices: [
            ("collect-the-bones", "Search the Bones", [
                item("ruby_amulet", trinkets: ["bone_charm"]),
                .gainMaterial(.iron),
            ]),
            ("claim-the-shield", "Recover the Hoard", [
                item("kite_shield", trinkets: ["vanguards_crest"], uniques: ["the_knights_answer"]),
                .gainGold(30),
            ]),
        ],
    )

    static let necromancersOffer = makeEvent(
        id: "necromancers-offer",
        title: "The Necromancer's Offer",
        narrative: "A necromancer offers {A} beside forbidden lessons, while crystal salts cradle {B}.",
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
        narrative: "A deserted lodge shelters {A}, and split logs surround {B} outside.",
        artID: "mystery-hunters-lodge",
        choices: [
            ("claim-the-bow", "Take the Weapon", [
                item("crossbow", uniques: ["blackfletch", "huntsmasters_call", "wrenflight"]),
                .gainMaterial(.hide),
            ]),
            ("take-the-hatchet", "Gather the Tools", [
                item("hatchet", uniques: ["the_unclosing_wound"]),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let roadsideCenser = makeEvent(
        id: "roadside-censer",
        title: "Roadside Censer",
        narrative: "Incense herbs surround {A} while a censer shelters {B} among pilgrims’ coins.",
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
        narrative: "A violet altar remakes gear forever, offering corruption or escape.",
        artID: "destination-corruption-altar",
        choices: [
            ("corrupt-item", "Corrupt an Item", [.corruptItem]),
            ("leave", "Leave", [.leave]),
        ],
    )
}
