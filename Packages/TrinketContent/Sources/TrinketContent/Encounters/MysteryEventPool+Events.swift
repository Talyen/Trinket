import Foundation
import TrinketCore

extension MysteryEventPool {
    static let manaBerries = makeEvent(
        id: "mana-berries",
        title: "Mana Berries",
        narrative: "Glowing berries surround {A}, and blue roots hum around {B}.",
        artID: "mystery-mana-berries",
        choices: [
            ("harvest-berries", "Harvest Berries", [
                item("sapphire_ring", uniques: ["winters_credit"], guaranteedAffixIDs: ["manabound"]),
                .gainMaterial(.herbs),
            ]),
            ("gather-crystals", "Study Roots", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let enchantedSpring = makeEvent(
        id: "enchanted-spring",
        title: "Enchanted Spring",
        narrative: "Beneath the spring, crystal traps {A} while healing ripples reveal {B}.",
        artID: "mystery-enchanted-spring",
        choices: [
            ("gather-the-moss", "Break the Crust", [
                item("sapphire_amulet", trinkets: ["icy_heart"], uniques: ["rimeheart_locket"]),
                .gainMaterial(.gems),
            ]),
            ("take-the-charm", "Read the Ripples", [
                item("emerald_ring", uniques: ["serpents_eye"]),
                .gainExperience,
            ]),
        ],
    )

    static let fungalGrotto = makeEvent(
        id: "fungal-grotto",
        title: "Fungal Grotto",
        narrative: "Medicinal caps surround {A} as drifting spores gather above {B}.",
        artID: "mystery-fungal-grotto",
        choices: [
            ("harvest-mushrooms", "Harvest the Caps", [
                item("emerald_amulet", trinkets: ["parasitic_bloom"]),
                .gainMaterial(.herbs),
            ]),
            ("collect-crystals", "Study the Spores", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let wisdomTree = makeEvent(
        id: "wisdom-tree",
        title: "Wisdom Tree",
        narrative: "Fallen boughs shelter {A}, and carved rings whisper lessons around {B}.",
        artID: "mystery-wisdom-tree",
        choices: [
            ("collect-branches", "Gather Boughs", [
                item("leather_buckler", trinkets: ["ironwood_buckler"], uniques: ["laughing_guard"]),
                .gainMaterial(.wood),
            ]),
            ("forage-herbs", "Read the Rings", [
                item("spellbook"),
                .gainExperience,
            ]),
        ],
    )

    static let fairyRing = makeEvent(
        id: "fairy-ring",
        title: "Fairy Ring",
        narrative: "Coins glimmer beside {A} while fairy lights dance around {B}.",
        artID: "mystery-fairy-ring",
        choices: [
            ("take-the-gold", "Take the Gift", [
                item("topaz_ring", trinkets: ["lucky_clover"]),
                .gainGold(25),
            ]),
            ("pick-mushrooms", "Learn the Dance", [
                item("leather_armor", uniques: ["dance_of_blades"]),
                .gainExperience,
            ]),
        ],
    )

    static let sacredGrove = makeEvent(
        id: "sacred-grove",
        title: "Sacred Grove",
        narrative: "Medicinal blooms surround {A}, and exposed roots trace healing rites near {B}.",
        artID: "mystery-sacred-grove",
        choices: [
            ("pick-the-blooms", "Gather the Blooms", [
                item("emerald_amulet", trinkets: ["groves_favor"], uniques: ["wildhearts_favor"]),
                .gainMaterial(.herbs),
            ]),
            ("take-the-ring", "Learn the Rite", [
                item("wand"),
                .gainExperience,
            ]),
        ],
    )

    static let mountainPass = makeEvent(
        id: "mountain-pass",
        title: "Mountain Pass",
        narrative: "An iron seam reveals {A}, and fallen timber traps {B} nearby.",
        artID: "mystery-mountain-pass",
        choices: [
            ("mine-the-cliffside", "Search the Seam", [
                item("mace", trinkets: ["thunderstone"], uniques: ["the_lingering_bell"]),
                .gainMaterial(.iron),
            ]),
            ("gather-herbs", "Clear the Trail", [
                item("hatchet", uniques: ["red_harvest"]),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let murkyPond = makeEvent(
        id: "murky-pond",
        title: "Murky Pond",
        narrative: "A heavy net lies beside {A} while worn wishing stones surround {B}.",
        artID: "mystery-murky-pond",
        choices: [
            ("catch-fish", "Haul the Net", [
                item("dagger", uniques: ["vipers_courtesy"]),
                .gainMaterial(.food),
            ]),
            ("pull-the-reeds", "Search the Stones", [
                item("topaz_ring", trinkets: ["wishing_well_coin"]),
                .gainGold(20),
            ]),
        ],
    )

    static let medicinalHerbGarden = makeEvent(
        id: "medicinal-herb-garden",
        title: "Medicinal Herb Garden",
        narrative: "Medicinal beds surround {A} as treatment notes lie beneath {B}.",
        artID: "mystery-medicinal-herb-garden",
        choices: [
            ("harvest-remedies", "Harvest Remedies", [
                item("emerald_amulet", trinkets: ["mortar_and_pestle"]),
                .gainMaterial(.herbs),
            ]),
            ("take-the-notes", "Read the Notes", [
                item("leather_armor", trinkets: ["plague_doctors_mask"]),
                .gainExperience,
            ]),
        ],
    )

    static let crystalGarden = makeEvent(
        id: "crystal-garden",
        title: "Crystal Garden",
        narrative: "Crystal blooms surround {A} while garden stones sing beside {B}.",
        artID: "mystery-crystal-garden",
        choices: [
            ("harvest-shards", "Harvest Shards", [
                item("sapphire_amulet", guaranteedAffixIDs: ["manabound"]),
                .gainMaterial(.gems),
            ]),
            ("take-the-chimes", "Learn the Melody", [
                item("wand", trinkets: ["resonant_chimes"]),
                .gainExperience,
            ]),
        ],
    )

    static let thePhoenix = makeEvent(
        id: "the-phoenix",
        title: "The Phoenix",
        narrative: "Red crystals cradle {A} as phoenix embers warm {B}.",
        artID: "mystery-the-phoenix",
        choices: [
            ("claim-the-feather", "Search the Nest", [
                item("ruby_ring", uniques: ["bloodfire_signet"]),
                .gainMaterial(.gems),
            ]),
            ("take-the-brand", "Gather the Embers", [
                item("staff"),
                .gainMaterial(.wood),
            ]),
        ],
    )

    static let theWolf = makeEvent(
        id: "the-wolf",
        title: "The Wolf",
        narrative: "A wolf’s abandoned camp holds {A} while dried meat waits beside {B}.",
        artID: "mystery-the-wolf",
        choices: [
            ("search-the-den", "Search the Kit", [
                item("leather_buckler", trinkets: ["companions_collar"], uniques: ["the_returning_flight"]),
                .gainMaterial(.hide),
            ]),
            ("open-the-cache", "Open the Cache", [
                item("recurve_bow", uniques: ["the_returning_gale"]),
                .gainMaterial(.food),
            ]),
        ],
    )

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
                .gainMaterial(.gems),
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
                .gainMaterial(.gems),
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
                .gainMaterial(.gems),
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
}
