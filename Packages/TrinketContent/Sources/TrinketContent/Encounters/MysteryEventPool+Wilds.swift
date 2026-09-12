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
                .gainMaterial(.crystal),
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
                .gainMaterial(.crystal),
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
                .gainMaterial(.crystal),
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
}
